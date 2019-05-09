unit LineParser_Interpreter1;

interface

uses LineParser_Base;
uses MiscTextManipulators;

uses ExprParser_Base; // ToDo #1933

type
  TextInterpreter1 = class(LineParserBase)
    
    public procedure ExecuteLine(l: string); override;
    begin
      if l.Contains('=') then // если есть "=" - значит у нас строчка с оператором присваения
      begin
        var ss := l.Split(new char[]('='),2);
        SetVar(
          ss[0],
          CalcExpr(ss[1])
        );
        exit;
      end;
      
      var ss := l.SmartSplit;
      case ss[0].ToLower of
        
        'output':
        begin
          if ss.Length<2 then raise new System.InvalidOperationException($'Недостаточно параметров на строчке "{l}", должен быть хотя бы 1');
          writeln(CalcExpr(ss[1]));
        end;
        
        else raise new System.InvalidOperationException($'Неизвестная команда "{ss[0]}"');
      end;
      
    end;
    
  end;

implementation

end.