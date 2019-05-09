unit MiscTextManipulators;

// иначе будет путаница со всеми .SubString и т.п., потому что они всё равно нумеруют с 0
// но это работает локально на модуль, в программе к которой подключили - всё по-обычному
{$string_nullbased+}

type
  CorrespondingCharNotFoundException = sealed class(Exception)
    
    constructor(text: string; ch: char; i1,i2: integer) :=
    inherited Create($'Соответствующий знак "{ch}" не найден в строке "{text}", в фрагменте "{text.Substring(i1,i2-i1+1)}"');
    
  end;

function FindNext(self: string; i1,i2: integer; ch: char): integer; extensionmethod;
begin
  var from := i1;
  while true do
  begin
    if from > i2 then raise new CorrespondingCharNotFoundException(self,ch, from,i2);
    
    if self[i1] = ch then
    begin
      Result := i1;
      exit;
    end;
    
    case self[i1] of
      '(': i1 := self.FindNext(i1+1,i2, ')');
      '"': i1 := self.FindNext(i1+1,i2, '"');
    end;
    
    i1 += 1;
  end;
end;

function SmartSplit(self: string; str: string := ' '; c: integer := -1): array of string; extensionmethod;
begin
  if (self = '') or (c = 0) then
  begin
    Result := new string[1]('');
    exit;
  end else
  if c = 1 then
  begin
    Result := new string[1](self);
    exit;
  end;
  
  c -= 1;
  var wsp := new List<integer>; // список координат всех вхождений str в self
  
  var n := 0;
  while n+str.Length <= self.Length do
  begin
    
    if Range(0,str.Length-1).All(i->self[n+i] = str[i]) then
    begin
      wsp += n;
      if wsp.Count = c then break;
    end else
    if self[n] = '(' then n := self.FindNext(n+1, self.Length-1, ')') else
    if self[n] = '"' then n := self.FindNext(n+1, self.Length-1, '"');
    
    n += 1;
  end;
  
  if wsp.Count=0 then
  begin
    Result := new string[](self);
    exit;
  end;
  
  Result := new string[wsp.Count+1];
  Result[0] := self.Remove(wsp[0]);
  
  for var i := 0 to wsp.Count-2 do
    Result[i+1] := self.Substring(wsp[i]+str.Length, wsp[i+1]-wsp[i]-1);
  
  Result[Result.Length-1] := self.Substring(wsp[wsp.Count-1]+str.Length);
end;

end.