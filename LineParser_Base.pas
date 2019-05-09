unit LineParser_Base;

uses ExprParser_Base;

type
  LineParserBase = abstract class
    
    private fParse: string->ExprParserBase;
    private vars := new Dictionary<string, object>;
    
    public constructor(fParse: string->ExprParserBase) :=
    self.fParse := fParse;
    
    
    
    protected procedure SetVar(vname: string; val: object) :=
    if val=nil then
      vars.Remove(vname) else
      vars[vname] := val;
    
    protected function CalcExpr(expr: string) :=
    fParse(expr).Calc(vars);
    
    
    
    public procedure ExecuteLine(l: string); abstract;
    
    public procedure ExecuteLines(lns: sequence of string) :=
    foreach var l in lns do ExecuteLine(l);
    
    public procedure ExecuteFile(fname: string) :=
    ExecuteLines(ReadLines(fname));
    
  end;

end.