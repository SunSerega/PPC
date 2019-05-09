unit ExprParser_Base;

type
  ExprParserBase = abstract class
    
    private static fi: System.IFormatProvider := new System.Globalization.NumberFormatInfo; // надо чтоб при конвертации 1.2 в строку - на русских системах не давало "1,2"
    
    public static function ObjToNum(o: object) :=
    o=nil?0.0:real(o);
    
    public static function ObjToStr(o: object) :=
    o=nil?'':System.Convert.ToString(o,fi);
    
    
    
    public function Calc(vars: Dictionary<string,object>): object; abstract;
    
    public function Calc := Calc(Dict&<string,object>);
    
  end;

end.