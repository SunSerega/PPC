
//парсервы выражений
uses ExprParser_Recurcive;
uses ExprParser_RPN;

//парсеры строк
uses LineParser_Interpreter1;

begin
  var p := new TextInterpreter1(expr->new RecurciveExprParser(expr));
  //var p := new TextInterpreter1(expr->new RPNExprParser(expr));
  
  p.ExecuteLine('x=(2+2)*2');
  p.ExecuteLine('Output x');
  
end.