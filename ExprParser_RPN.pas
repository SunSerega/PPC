unit ExprParser_RPN;
//Парсинг с помощью Обратной Польской Записи
//
//Преимущества:
// - Алгоритм не рекурсивный
// - Минимум дополнительных типов
//
//Недостатки:
// - алгоритм парсера требует вдуматься в него чтоб он стал интуитевен
// - возможности вывода ошибок ограничены, некоторыми костылями можно сделать его интуитивным пользователю компилятора, но это сильно его усложнит

interface

uses ExprParser_Base;

type
  RPNExprParser = sealed class(ExprParserBase)
    private e: object;
    
    public constructor(text: string);
    
    public function Calc(vars: Dictionary<string,object>): object; override;
    
  end;

implementation

type
  ExprPart = abstract class end;
  ExprOperT = (plus, minus, mlt, dvd, pow);
  
  ValueExprPart = sealed class(ExprPart)
    
    public v: string;
    
    public constructor(v: string) :=
    self.v := v;
    
  end;
  OperExprPart = sealed class(ExprPart)
    
    public op: ExprOperT;
    
    public constructor(op: ExprOperT) :=
    self.op := op;
    
  end;
  OpnBracketExprPart = sealed class(ExprPart)
    
    public constructor := exit;
    
  end;
  ClsBracketExprPart = sealed class(ExprPart)
    
    public constructor := exit;
    
  end;
  
function SplitIntoExprParts(text: string): sequence of ExprPart;
begin
  
  var sb := new StringBuilder;
  
  foreach var ch in text do
    case ch of
      
      '+','-','*','/','^','(',')':
      begin
        if sb.Length<>0 then yield new ValueExprPart(sb.ToString);
        sb.Clear;
        
        case ch of
          
          '+': yield new OperExprPart(plus);
          '-': yield new OperExprPart(minus);
          '*': yield new OperExprPart(mlt);
          '/': yield new OperExprPart(dvd);
          '^': yield new OperExprPart(pow);
          
          '(': yield new OpnBracketExprPart;
          ')': yield new ClsBracketExprPart;
          
        end;
        
      end;
      
      else sb += ch;
    end;
  
  if sb.Length<>0 then yield new ValueExprPart(sb.ToString);
  
end;

function ConvertExpr(expr: sequence of ExprPart): sequence of ExprPart;
begin
  var st := new Stack<ExprPart>;
  
  foreach var entr in expr do
    match entr with
      
      ValueExprPart(var vep): yield entr;
      
      OperExprPart(var oep):
      begin
        
        case oep.op of
          
          plus, minus:
          begin
            
            // пропускаем все операторы с более высоким приоритетом
            while (st.Count<>0) and (st.Peek is OperExprPart) and ((st.Peek as OperExprPart).op > minus) do
              yield st.Pop;
            
            // и чтоб из 1-2-3 не вышло ((2-3)-1) пропускаем ещё 1 оператор с тем же приоритетом
            if (st.Count<>0) and (st.Peek is OperExprPart) then
              case (st.Peek as OperExprPart).op of
                plus,minus: yield st.Pop;
              end;
            
            st.Push(entr);
          end;
          
          mlt, dvd:
          begin
            
            while (st.Count<>0) and (st.Peek is OperExprPart) and ((st.Peek as OperExprPart).op > dvd) do
              yield st.Pop;
            
            if (st.Count<>0) and (st.Peek is OperExprPart) then
              case (st.Peek as OperExprPart).op of
                mlt,dvd: yield st.Pop;
              end;
            
            st.Push(entr);
          end;
          
          pow:
          begin
            
            if (st.Count<>0) and (st.Peek is OperExprPart) then
              case (st.Peek as OperExprPart).op of
                pow: yield st.Pop;
              end;
            
            st.Push(entr);
          end;
          
        end;
        
      end;
      
      OpnBracketExprPart(var br): st.Push(entr);
      
      ClsBracketExprPart(var br):
      begin
        
        while not (st.Peek is OpnBracketExprPart) do
          yield st.Pop;
        
        st.Pop;
      end;
      
      else raise new System.NotImplementedException;
      
    end;
  
  yield sequence st;
  
end;

function EvalExpr(expr: sequence of ExprPart; vars: Dictionary<string,object>): object;
begin
  var st := new Stack<object>;
  
  foreach var entr in expr do
    match entr with
      
      ValueExprPart(var vep):
      begin
        var text := vep.v;
        
        if text[1] = '"' then
        begin
          if text[text.Length] <> '"' then raise new System.InvalidOperationException($'В строке {text} не хватило " на конце');
          st.Push(text.Substring(1,text.Length-2));
        end else
        
        if text[1].IsDigit then // если начинается с цифры - число
        try
          st.Push(text.ToReal);
        except
          on System.FormatException do raise new System.InvalidOperationException($'Не удалось преобразовать {text} в число');
        end else
        
        if text.All(ch->(ch='_') or ch.IsLetter) then
        case text.ToLower of
          
          'nil': st.Push(nil);
          'inf': st.Push(real.PositiveInfinity);
          'nan': st.Push(real.NaN);
          
          else st.Push(vars.ContainsKey(text)?vars[text]:nil);
        end else
          
          raise new System.InvalidOperationException($'Переменная не может называться {text}, имя переменной должно содержать только буквы и "_"');
        
      end;
      
      OperExprPart(var oep):
      begin
        var o2 := st.Pop;
        var o1 := st.Pop;
        
        if (o1 is string) or (o2 is string) then
        case oep.op of
          
          plus:   st.Push(ExprParserBase.ObjToStr(o1) + ExprParserBase.ObjToStr(o2));
          minus:  raise new System.NotSupportedException('Нельзя отнимать от строк!');
          mlt:    raise new System.NotSupportedException('Нельзя умножать строки!');
          dvd:    raise new System.NotSupportedException('Нельзя делить строки!');
          pow:    raise new System.NotSupportedException('Нельзя возводить строки в степень!');
          
        end else
        case oep.op of
          
          plus:   st.Push(ExprParserBase.ObjToNum(o1) + ExprParserBase.ObjToNum(o2));
          minus:  st.Push(ExprParserBase.ObjToNum(o1) - ExprParserBase.ObjToNum(o2));
          mlt:    st.Push(ExprParserBase.ObjToNum(o1) * ExprParserBase.ObjToNum(o2));
          dvd:    st.Push(ExprParserBase.ObjToNum(o1) / ExprParserBase.ObjToNum(o2));
          pow:    st.Push(ExprParserBase.ObjToNum(o1) ** ExprParserBase.ObjToNum(o2));
          
        end;
        
      end;
      
    end;
  
  Result := st.Pop;
end;

constructor RPNExprParser.Create(text: string) :=
self.e := ConvertExpr(SplitIntoExprParts(text)).ToList;

function RPNExprParser.Calc(vars: Dictionary<string,object>): object :=
EvalExpr(List&<ExprPart>(self.e), vars);

end.