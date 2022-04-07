// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.7;

// ----------------------------------------------------------------------------
// EIP-20: ERC-20 Token Standard
// https://eips.ethereum.org/EIPS/eip-20
// -----------------------------------------

// ChanChanChan 컨트랙트에서 사용할 함수를 선언한다.
interface ERC20Interface {
    // ERC-20 토큰의 총 발행량 확인
    function totalSupply() external view returns (uint);
    // tokenOwner가 가지고 있는 토큰의 보유량 확인
    function balanceOf(address tokenOwner) external view returns (uint balance);
    // 토큰을 전송
    function transfer(address to, uint tokens) external returns (bool success);
    // tokenOwner가 spender에게 양도 설정한 토큰의 양을 확인한다
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    // spender 에게 value 만큼의 토큰을 인출할 권리를 부여. 이 함수를 이용할 때는 반드시 Approval 이벤트 함수를 호출해야 한다.
    function approve(address spender, uint tokens) external returns (bool success);
    // spender가 거래 가능하도록 양도 받은 토큰을 전송한다.
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    
    // 토큰이 이동할 때마다 로그를 남긴다.
    event Transfer(address indexed from, address indexed to, uint tokens);
    // approve 함수가 실행 될 때 로그를 남긴다.
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// ChanChanChan 컨트랙트 안에서 ERC20Interface에 선언된 함수와 이벤트를 사용한다.
contract ChanChanChan is ERC20Interface{
    string public name = "ChanChanChan";
    string public symbol = "CHCHCH";
    uint public decimals = 0; 
    uint public override totalSupply;
    
    address public founder;
    mapping(address => uint) public balances;
    
    mapping(address => mapping(address => uint)) allowed;
    
    constructor(){
      totalSupply = 1000000;
      founder = msg.sender;
      balances[founder] = totalSupply;
    }
    
    function balanceOf(address tokenOwner) public view override returns (uint balance){
      return balances[tokenOwner];
    }
    // virtual을 통해 상속 ICO 컨트랙트에서 transfer를 수정할 수 있도록 한다. 
    function transfer(address to, uint tokens) public virtual override returns(bool success){
      require(balances[msg.sender] >= tokens);
        
      balances[to] += tokens;
      balances[msg.sender] -= tokens;
      emit Transfer(msg.sender, to, tokens);
        
      return true;
    }
    
    function allowance(address tokenOwner, address spender) view public override returns(uint){
      return allowed[tokenOwner][spender];
    }
    
    function approve(address spender, uint tokens) public override returns (bool success){
      require(balances[msg.sender] >= tokens);
      require(tokens > 0);
        
      allowed[msg.sender][spender] = tokens;
        
      emit Approval(msg.sender, spender, tokens);
      return true;
    }
    
    // virtual을 통해 상속 ICO 컨트랙트에서 transferFrom을 수정할 수 있도록 한다. 
    function transferFrom(address from, address to, uint tokens) public virtual override returns (bool success){
      require(allowed[from][to] >= tokens);
      require(balances[from] >= tokens);
         
      balances[from] -= tokens;
      balances[to] += tokens;
      allowed[from][to] -= tokens;
        
      emit Transfer(from, to, tokens);
       
      return true;
    }
}

// ERC20 토큰 ChanChanChan 컨트랙트를 상속하여 새 컨트랙트 ChanChanChanICO를 선언한다.
contract ChanChanChanICO is ChanChanChan{
  // ICO에는 컨트랙트 배포 계정인 관리자가 있어 긴급 상황이 발생하면 ICO를 중지할 수 있고, 손상될 경우 예금 주소를 변경할 수 있다.
  address public admin;
  // 컨트랙트에 전송된 Ether로 전송되는 주소. 투자자는 Eth를 컨트랙트 주소로 보낸다.
  // Ether는 자동으로 입금 주소로 전송되고 암호화폐는 투자자의 잔액에 추가된다.
  // 이 방법은 컨트랙트에 이더를 저장하는 것보다 안전하다.
  address payable public deposit;
  // 1ETH == 1000 CHCHCH, 1CHCHCH = 0.001ETH
  uint tokenPrice = 0.001 ether; 
  // ICO에는 투자할 수 있는 최대 이더(하드캡)가 있고, 300이더로 설정한다.
  uint public hardCap = 300 ether;
  // ICO로 전송된 이더의 총량을 보유하는 raiseAmount변수를 선언힌
  uint public raisedAmount;
  // ICO에는 시작 날짜와 종료 날짜가 있으므로 바로 시작할 필요는 없다. 
  // 예) block.timestamp + 3600 : 1시간 뒤에 시작.
  uint public saleStart = block.timestamp;
  // 바로 시작해서 일주일 후에 종료되도록 한다.
  uint public saleEnd = block.timestamp + 604800;
  // 초기 투자자들이 토큰을 시장에 버려 가격이 폭락하지 않도록 
  // ICO가 끝난 후 일주일 후에 토큰을 전송할 수 있도록 한다.
  uint public tokenTradeStart = saleEnd + 604800;
  // 최소 및 최대 투자금액을 설정한다.
  uint public minInvestment = 0.1 ether;
  uint public maxInvestment = 5 ether;

  // ICO의 4가지 상태를 가지는 enum 변수를 선언한다.
  enum State {beforeStart, running, afterEnd, halted}
  State public icoState;

  constructor(address payable _deposit){ 
    // deposit 주소를 초기화한다.
    deposit = _deposit;
    // 관리자를 컨트랙트 배포 주소로 초기화한다.
    // deposit 및 admin은 같은 주소일 수도, 아닐수도 있다.
    admin = msg.sender;
    // ICO는 배포 후에 시작된다.
    icoState = State.beforeStart;
  }

  // 관리자만 호출 가능한 함수에 적용할 onlyAdmin modifier를 선언한다. 
  modifier onlyAdmin(){
    require(msg.sender == admin);
    _;
  }
  // 관리자는 문제 발생 시 언제든지 ICO를 중지할 수 있어야 한다. 
  function halt() public onlyAdmin{
    icoState = State.halted;
  }
  // 관리자는 문제가 해결된 후 ICO를 다시 시작할 수 있어야 한다.
  function resume() public onlyAdmin{
    icoState = State.running;
  }
  // 관리자는 또한 deposit 주소에 문제가 생긴 경우 변경할 수 있다.
  function changeDepositAddress(address payable newDeposit) public onlyAdmin{
    deposit = newDeposit;
  }

  // ICO의 상태를 리턴하는 함수 getCurrentState 선언 (상태를 변경하지 않는 읽기 전용 함수)
  function getCurrentState() public view returns(State){
    // ICO 중지 상태.
    if(icoState == State.halted){
      return State.halted;
    // ICO 시작 전.
    }else if(block.timestamp < saleStart){
      return State.beforeStart;
    // ICO 진행 중.
    }else if(block.timestamp >= saleStart && block.timestamp <= saleEnd){
      return State.running;
    // ICO 종료.
    }else{
      return State.afterEnd;
    }
  }
  // (프론트엔드에서 처리) 블록체인에 기록될 로그 메시지인 이벤트를 선언한다.
  event Invest(address investor, uint value, uint tokens);

  // Invest는 ICO의 주요 기능이며 투자자는 Front-End 앱을 사용하여 이 함수를 호출하고 
  // 지갑으로 보내거나 ICO 주소로 직접 보내어 암호화폐를 구입할 수 있다.
  // Invest 함수는 누군가 ETH를 컨트랙트에 보내고 ETH를 수신할 때 호출된다.
  function invest() payable public returns (bool){
    // ICO가 실행 중이어야 한다.
    icoState = getCurrentState();
    require(icoState == State.running);

    // 또한 컨트랙트에 전송된 값이 최소 투자비용과 최대 투자비용 사이에 있어야 한다.
    require(msg.value >= minInvestment && msg.value <= maxInvestment);

    // 또한 ICO가 정해놓은 hardCap에 도달하지 않았어야 한다.
    raisedAmount += msg.value;
    require(raisedAmount <= hardCap);

    // 투자자가 방금 보낸 Ether에 대해 얻을 토큰 수를 계산한다.
    // 보낸 wei의 수를 wei의 토큰 가격으로 나눈다.
    uint tokens = msg.value / tokenPrice;
    // 계산으로 나온 금액만큼 해당 토큰을 투자자의 잔액에 추가하고 founder 잔액에서 뺀다.
    // balances는 ERC20 토큰 컨트랙트에서 선언되고 ICO 컨트랙트로 상속된 매핑 변수이다.
    balances[msg.sender] += tokens;
    balances[founder] -= tokens;
    // 보낸 금액을 deposit 주소로 전송한다.
    deposit.transfer(msg.value);
    // 투자자 주소 및 보낸 금액, 방금 구매한 토큰 수를 이벤트로 내보낸다.
    emit Invest(msg.sender, msg.value, tokens);
    
    return true;
  }
  // 이 함수는 누군가 Ether를 컨트랙트 주소로 직접 보낼 때 호출된다. 
  receive() payable external{
    invest();
  }
  // transfer()는 소유자가 자신의 토큰을 다른 계정으로 전송하기 위해 호출하며
  // transferFrom()은 소유자가 자신이 소유한 토큰을 사용하기 위해 다른 주소를 승인한 후 토큰 소유자를 대신하여 호출된다.
  // 이 2가지 함수를 재정의하여 토큰 잠금 기능을 추가한다. 
  function transfer(address to, uint tokens) public override returns(bool success){
    // 현재 날짜와 시간이 컨트랙트 상태 변수인 tokenTradeStart보다 큰 경우에만 토큰을 전송할 수 있다.
    require(block.timestamp > tokenTradeStart);
    ChanChanChan.transfer(to, tokens);
    return true;
  }
  function transferFrom(address from, address to, uint tokens) public override returns (bool success){
    require(block.timestamp > tokenTradeStart);
    ChanChanChan.transferFrom(from, to, tokens);
    return true;
  }
  // ICO에 모금된 금액이 HardCap(300 ETH) 미만인 경우 남은 토큰을 소각한다. (이는 일반적으로 가격상승으로 이어진다.)
  // 이 함수는 관리자뿐만 아니라 누구나 호출할 수 있다. (관리자가 마음을 바꾸어도 결국 토큰을 소각되어야 한다.)
  function burn() public returns(bool){
    icoState = getCurrentState();
    // 토큰은 ICO가 종료된 후에만 소각된다.
    require(icoState == State.afterEnd);
    // 남은 토큰을 없앤다. 토큰을 다시 생성할 수 있는 코드는 컨트랙트에 없다. 
    balances[founder] = 0;
    return true;
  }
}