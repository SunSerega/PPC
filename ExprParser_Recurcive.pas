unit ExprParser_Recurcive;
//Парсинг выражений путём разбиение на под-выражения и парсинга каждого отдельно
// 
//Преимущества:
// - алгоритм парсера прост в понимании
// - вывод адекватных ошибок легко сделать, и ошибки всегда будут максимально интуитивны пользователю компилятора
//
//Недостатки:
// - Рекурсивность. А значит на определённой вложенности выражений - будет переполнение стека
// - Используется множество вспомогательных классов, поэтому эффективность и по памяти, и по скорости - не очень

interface

uses ExprParser_Base;

type
  RecurciveExprParser = sealed class(ExprParserBase)
    private e: object; // не хорошо что object, но ExprBase нельзя объявить приватным классом, а для инкапсуляции лучше уже так
    
    public constructor(text: string);
    
    public function Calc(vars: Dictionary<string,object>): object; override;
    
  end;

implementation

uses MiscTextManipulators;

type
  ExprBase = abstract class
    
    function Calc(vars: Dictionary<string,object>): object; abstract;
    
  end;
  
  LiteralExpr = sealed class(ExprBase)
    res: object;
    
    constructor(o: object) := res := o;
    
    function Calc(vars: Dictionary<string,object>): object; override := res;
    
  end;
  VarExpr = sealed class(ExprBase)
    name: string;
    
    constructor(name: string) :=
    self.name := name;
    
    function Calc(vars: Dictionary<string,object>): object; override :=
    vars.ContainsKey(name)?
    vars[name]:nil;
    
  end;
  
  PlusExpr = sealed class(ExprBase)
    Positive := new List<ExprBase>;
    Negative := new List<ExprBase>;
    
    function Calc(vars: Dictionary<string,object>): object; override;
    begin
      var P := Positive.ConvertAll(e->e.Calc(vars));
      var N := Negative.ConvertAll(e->e.Calc(vars));
      
      if P.Concat(N).Any(o->o is string) then // если есть хоть 1 строка - конвертируем всё в строки и складываем их
      begin
        if N.Any then raise new System.NotSupportedException('Нельзя отнимать от строк!');
        var res := new StringBuilder;
        
        foreach var o in P do res += ExprParserBase.ObjToStr(o);
        
        Result := res;
      end else // если нет строк - складываем всё как real
      begin
        var res := 0.0;
        
        foreach var r in P.Where(o->o<>nil).Cast&<real> do res += r;
        foreach var r in N.Where(o->o<>nil).Cast&<real> do res -= r;
        
        Result := res;
      end;
      
    end;
    
  end;
  MltExpr = sealed class(ExprBase)
    Positive := new List<ExprBase>;
    Negative := new List<ExprBase>;
    
    function Calc(vars: Dictionary<string,object>): object; override;
    begin
      var P := Positive.ConvertAll(e->e.Calc(vars));
      var N := Negative.ConvertAll(e->e.Calc(vars));
      
      if P.Concat(N).Any(o->o is string) then
      begin
        raise new System.NotSupportedException('Нельзя умножать/делить строки!');
      end else
      begin
        var res := 1.0;
        
        // все nil специально конвертируем в 0, в PlusExpr это было бесполезно, но тут надо для однообразия
        foreach var r in P.Select(ExprParserBase.ObjToNum) do res *= r;
        foreach var r in N.Select(ExprParserBase.ObjToNum) do res /= r;
        
        Result := res;
      end;
      
    end;
    
  end;
  PowExpr = sealed class(ExprBase)
    Positive := new List<ExprBase>;
    
    function Calc(vars: Dictionary<string,object>): object; override;
    begin
      var P := Positive.ConvertAll(e->e.Calc(vars));
      
      if P.Any(o->o is string) then
      begin
        raise new System.NotSupportedException('Нельзя возводить строки в степень!');
      end else
      begin
        var base := ExprParserBase.ObjToNum(P[0]);
        
        // "1^2^3" мы расцениваем как ((1^2)^3), а значит степени можно просто перемножить
        // умножение считается на много быстрее степени, поэтому это очень полезно
        var exp := 1.0;
        foreach var r in P.Skip(1).Select(ExprParserBase.ObjToNum) do exp *= r;
        
        Result := base ** exp;
      end;
      
    end;
    
  end;
  
  ExprT = (simple_expr, pow_expr, mlt_expr, plus_expr);
  
// иначе будет путаница со всеми .SubString и т.п., потому что они всё равно нумеруют с 0
// но это работает локально на модуль, в программе к которой подключили - всё по-обычному
{$string_nullbased+}

function ParseSimpleExpr(text: string; i1,i2: integer): ExprBase;
begin
  if text[i1] = '"' then
  begin
    Result := new LiteralExpr(text.Substring(i1+1,i2-i1-1)); // проверять закрывающую " не нужно, если бы её небыло - была бы ошибка в ParseComplexExpr
    exit;
  end;
  
  text := text.Substring(i1,i2-i1+1);
  
  if text[0].IsDigit then // если начинается с цифры - число
  try
    Result := new LiteralExpr(text.ToReal);
  except
    on System.FormatException do raise new System.InvalidOperationException($'Не удалось преобразовать {text} в число');
  end else
  if text.All(ch->(ch='_') or ch.IsLetter) then
  case text.ToLower of
    
    'nil': Result := new LiteralExpr(nil);
    'inf': Result := new LiteralExpr(real.PositiveInfinity);
    'nan': Result := new LiteralExpr(real.NaN);
    
    else Result := new VarExpr(text);
  end else
    raise new System.InvalidOperationException($'Переменная не может называться {text}, имя переменной должно содержать только буквы и "_"');
  
end;

function ParseComplexExpr(text: string; i1,i2: integer): ExprBase;
begin
  if (text[i1]='(') and (text.FindNext(i1+1,i2,')') = i2) then
  begin
    Result := ParseComplexExpr(text, i1+1,i2-1);
    exit;
  end;
  
  var from := i1;
  
  var expr_t := ExprT.simple_expr;
  
  // в самом начале строки может стоять минус (ну и плюс ибо почему нет, его легко обработать)
  var fst_neg := false;
  if (text[i1]='+') then i1 += 1;
  if (text[i1]='-') then
  begin
    i1 += 1;
    fst_neg := true;
    expr_t := ExprT.plus_expr;
  end;
  
  var sub_exprs_coords := new List<integer>;
  var fst_coord := i1;
  
  while i1<=i2 do
  begin
    case text[i1] of
      '+','-', '*','/', '^': sub_exprs_coords += i1+1;
    end;
    
    case text[i1] of
      '(': i1 := text.FindNext(i1+1,i2, ')');
      '"': i1 := text.FindNext(i1+1,i2, '"');
      
      '+','-': if expr_t<ExprT.plus_expr then expr_t := ExprT.plus_expr;
      '*','/': if expr_t<ExprT.mlt_expr  then expr_t := ExprT.mlt_expr;
      '^':     if expr_t<ExprT.pow_expr  then expr_t := ExprT.pow_expr;
    end;
    
    i1 += 1;
  end;
  
  case expr_t of
    ExprT.plus_expr: sub_exprs_coords.RemoveAll(i-> (text[i-1]<>'+') and (text[i-1]<>'-') );
    ExprT.mlt_expr:  sub_exprs_coords.RemoveAll(i-> (text[i-1]<>'*') and (text[i-1]<>'/') );
    ExprT.pow_expr:  sub_exprs_coords.RemoveAll(i-> (text[i-1]<>'^') );
  end;
  
  sub_exprs_coords += i2+2;
  
  case expr_t of
    ExprT.simple_expr: Result := ParseSimpleExpr(text, from, i2);
    
    ExprT.plus_expr:
    begin
      var res := new PlusExpr;
      
      (fst_neg?res.Negative:res.Positive).Add(
        ParseComplexExpr(text, fst_coord, sub_exprs_coords[0]-2)
      );
      
      foreach var t in sub_exprs_coords.Pairwise do
        (text[t[0]-1]='-'?res.Negative:res.Positive).Add(
          ParseComplexExpr(text, t[0], t[1]-2)
        );
      
      Result := res;
    end;
    
    ExprT.mlt_expr:
    begin
      var res := new MltExpr;
      
      res.Positive += ParseComplexExpr(text, fst_coord, sub_exprs_coords[0]-2);
      
      foreach var t in sub_exprs_coords.Pairwise do
        (text[t[0]-1]='/'?res.Negative:res.Positive).Add(
          ParseComplexExpr(text, t[0], t[1]-2)
        );
      
      Result := res;
    end;
    
    ExprT.pow_expr:
    begin
      var res := new PowExpr;
      
      res.Positive += ParseComplexExpr(text, fst_coord, sub_exprs_coords[0]-2);
      
      foreach var t in sub_exprs_coords.Pairwise do
        res.Positive += ParseComplexExpr(text, t[0], t[1]-2);
      
      Result := res;
    end;
    
  end;
  
end;

constructor RecurciveExprParser.Create(text: string) :=
self.e := ParseComplexExpr(text, 0, text.Length-1);

function RecurciveExprParser.Calc(vars: Dictionary<string,object>): object :=
ExprBase(self.e).Calc(vars);

end.