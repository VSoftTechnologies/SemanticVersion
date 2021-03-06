﻿{***************************************************************************}
{                                                                           }
{           VSoft.SemanticVErsion - Semantic Version Parsing                }
{                                                                           }
{           Copyright © 2017 Vincent Parrett and contributors               }
{                                                                           }
{           vincent@finalbuilder.com                                        }
{           https://www.finalbuilder.com                                    }
{                                                                           }
{                                                                           }
{***************************************************************************}
{                                                                           }
{  Licensed under the Apache License, Version 2.0 (the "License");          }
{  you may not use this file except in compliance with the License.         }
{  You may obtain a copy of the License at                                  }
{                                                                           }
{      http://www.apache.org/licenses/LICENSE-2.0                           }
{                                                                           }
{  Unless required by applicable law or agreed to in writing, software      }
{  distributed under the License is distributed on an "AS IS" BASIS,        }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{  See the License for the specific language governing permissions and      }
{  limitations under the License.                                           }
{                                                                           }
{***************************************************************************}

unit VSoft.SemanticVersion;

interface


type
  TSemanticVersion = record
  private
    FPreReleaseTag    : string;
    FMetaData : string;
    FElements : array[0..2] of Cardinal; //version numbers are typically 16 bit unsigned integers
    constructor CreateEmpty(const dummy : integer);
    function GetIsStable : boolean;
    function GetIsEmpty : boolean;
    class function IsDigit(const value : Char) : boolean;static;
    class function CompareTags(const a, b : string) : integer;static;
  public
    constructor Create(const major, minor : Cardinal);overload;
    constructor Create(const major, minor : Cardinal; const preReleaseTag : string );overload;
    constructor Create(const major, minor, patch : Cardinal);overload;
    constructor Create(const major, minor, patch : Cardinal; const preReleaseTag : string; const metaData : string );overload;

    function Clone : TSemanticVersion;
    function CompareTo(const version : TSemanticVersion) : integer;
    function ToString : string;
    function ToStringNoMeta : string;

    class function Parse(const version : string) : TSemanticVersion;static;
    class function TryParse(const version : string; out value : TSemanticVersion) : boolean;static;
    class function TryParseWithError(const version : string; out value : TSemanticVersion; out error : string) : boolean;static;
    class function Empty : TSemanticVersion; static;

    class operator Equal(a: TSemanticVersion; b: TSemanticVersion) : boolean;
    class operator NotEqual(a : TSemanticVersion; b : TSemanticVersion) : boolean;
    class operator GreaterThan(a : TSemanticVersion; b : TSemanticVersion) : boolean;
    class operator GreaterThanOrEqual(a : TSemanticVersion; b : TSemanticVersion) : boolean;
    class operator LessThan(a : TSemanticVersion; b : TSemanticVersion) : boolean;
    class operator LessThanOrEqual(a : TSemanticVersion; b : TSemanticVersion) : boolean;

    property Major    : Cardinal read FElements[0] write FElements[0];
    property Minor    : Cardinal read FElements[1] write FElements[1];
    property Patch  : Cardinal read FElements[2] write FElements[2];
    property PreReleaseTag : string read FPreReleaseTag write FPreReleaseTag;
    property IsStable : boolean read GetIsStable;
    property IsEmpty  : boolean read GetIsEmpty;
    property MetaData : string read FMetaData write FMetaData;
  end;

implementation

uses
  System.StrUtils,
  System.SysUtils;

{ TSemanticVersion }

function TSemanticVersion.Clone: TSemanticVersion;
begin
  result := TSemanticVersion.Create(Major, Minor, Patch, PreReleaseTag, MetaData);
end;

function Max(const a, b : integer) : integer;
begin
  if a > b then
    result := a
  else
    result := b;
end;

function CompareInt(const a, b : integer) : integer;
begin
  result := 0;
  if a > b  then
    result := 1
  else if a < b then
    result := -1;
end;

//borrowed from stringhelper, works in more versions of delphi
function SplitStr(const value : string; const Separator: Char): TArray<string>;
const
  DeltaGrow = 4; //we are not likely to need a lot
var
  NextSeparator, LastIndex: Integer;
  Total: Integer;
  CurrentLength: Integer;
  s : string;
begin
  Total := 0;
  LastIndex := 1;
  CurrentLength := 0;
  NextSeparator := PosEx(Separator,value, LastIndex);
  while (NextSeparator > 0)  do
  begin
    s := Copy(value, LastIndex, NextSeparator - LastIndex);
    if (S <> '') or (S = '') then
    begin
      Inc(Total);
      if CurrentLength < Total then
      begin
        CurrentLength := Total + DeltaGrow;
        SetLength(Result, CurrentLength);
      end;
      Result[Total - 1] := S;
    end;
    LastIndex := NextSeparator + 1;
    NextSeparator :=  PosEx(Separator,value, LastIndex);
  end;

  if (LastIndex <= Length(value)) then
  begin
    Inc(Total);
    SetLength(Result, Total);
    Result[Total - 1] := Copy(value,LastIndex, Length(value) - LastIndex + 1);
  end
  else
    SetLength(Result, Total);
end;


class function TSemanticVersion.CompareTags(const a, b: string): integer;
var
  i      : integer;
  aLen   : integer;
  bLen   : integer;
  maxLen : integer;

  sA     : string;
  sB     : string;
  iA     : integer;
  iB     : integer;
  aIsNumeric : boolean;
  bIsNumeric : boolean;
  aParts : TArray<string>;
  bParts : TArray<string>;
begin
  result := 0;
  aParts := SplitStr(a,'.');
  bParts := SplitStr(b,'.');

  aLen := Length(aParts);
  bLen := Length(bParts);
  //both should have at least 1 element, otherwise we should not have gotten here!
  Assert(aLen >= 1);
  Assert(bLen >= 1);

  maxLen := Max(aLen, bLen);

  for i := 0 to maxLen -1 do
  begin
    sA := '';
    sB := '';
    iA := -1;
    iB := -1;
    aIsNumeric := false;
    bIsNumeric := false;
    if i < aLen then
    begin
      sA := aParts[i];
      iA := StrToIntDef(sA, -1);
      aIsNumeric := iA <> -1;
    end;
    if i < bLen then
    begin
      sB := bParts[i];
      iB := StrToIntDef(sB, -1);
      bIsNumeric := iB <> -1;
    end;

    //if the string values are exactly the continue
    if CompareStr(sA, sB) = 0 then
      continue;

    if sA = '' then
      exit(-1);
    if sB = '' then
      exit(1);

    if aIsNumeric and bIsNumeric then
    begin
      result := iA - iB;// CompareInt(iA,iB);
      if result <> 0 then
        exit
      else
        continue;
    end
    else if (not aIsNumeric) and (not bIsNumeric) then
    begin
      result := CompareStr(sA,sB);
      if result <> 0 then
        exit
      else
        continue;
    end
    else if aIsNumeric and (not bIsNumeric) then
    begin
      exit(-1);
    end
    else
      exit(1);
  end;
end;

function TSemanticVersion.CompareTo(const version: TSemanticVersion): integer;
var
  i: Integer;
begin
  for i := 0 to 2 do
  begin
    result := FElements[i] - version.FElements[i];
    if result <> 0 then
      exit;
  end;

  //if we get here, version fields are equal.. so compare the Tags
  // Tag < no Tag
  if CompareStr(Self.PreReleaseTag,version.PreReleaseTag) <> 0 then
  begin
    if Self.PreReleaseTag = '' then
      Exit(1) //self greater than version
    else if version.PreReleaseTag = '' then
      Exit(-1); //self less than version
    Result := TSemanticVersion.CompareTags(self.PreReleaseTag, version.PreReleaseTag);
  end
  else
    result := 0;
end;

constructor TSemanticVersion.Create(const major, minor: Cardinal);
begin
  Create(major,minor,0,'','');
end;

constructor TSemanticVersion.Create(const major, minor, patch: Cardinal);
begin
  Create(major, minor, patch, '','');
end;

constructor TSemanticVersion.CreateEmpty(const dummy: integer);
begin
  FElements[0] := 0;
  FElements[1] := 0;
  FElements[2] := 0;
  FPreReleaseTag := '';
  FMetaData := '';
end;

class function TSemanticVersion.Empty: TSemanticVersion;
begin
  result := TSemanticVersion.CreateEmpty(0);
end;

class operator TSemanticVersion.Equal(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) = 0;
end;


function TSemanticVersion.GetIsEmpty: boolean;
begin
  result := (Major = 0) and (Minor = 0) and (Patch = 0);
end;

function TSemanticVersion.GetIsStable: boolean;
begin
  result := FPreReleaseTag = '';
end;

class operator TSemanticVersion.GreaterThan(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) > 0;
end;

class operator TSemanticVersion.GreaterThanOrEqual(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) >= 0;
end;

class function TSemanticVersion.IsDigit(const value: Char): boolean;
const
  digits  = ['0'..'9'];
begin
  result := CharInSet(value,digits);
end;

class operator TSemanticVersion.LessThan(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) < 0;
end;

class operator TSemanticVersion.LessThanOrEqual(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) <= 0;
end;

class operator TSemanticVersion.NotEqual(a, b: TSemanticVersion): boolean;
begin
  result := a.CompareTo(b) <> 0;
end;


class function TSemanticVersion.Parse(const version: string): TSemanticVersion;
var
  len : integer;
  i : integer;
  e : integer;
  currentElement : string;
  sValue : string;
  count : integer;
  TagStart : integer;

  procedure ParseMetaData;
  begin
    Inc(i);
    if i <= len then
      result.FMetaData := Copy(sValue,i,len);
    i := len + 1;
  end;

  procedure ParseTag;
  begin
    Inc(i);
    TagStart := i;
    while i <= len do
    begin
      if sValue[i] <> '+' then
        Inc(i)
      else
        break;
    end;
    result.FPreReleaseTag := Copy(sValue,TagStart,i - TagStart);
    if sValue[i] = '+' then
    begin
      ParseMetaData;
    end;
  end;

  function IsDecimalInteger(const value : string): Boolean;
  var
    i : integer;
  begin
    result := true;
    for i := 1 to Length(value) do
      if not TSemanticVersion.IsDigit(value[i]) then
      begin
        Result := False;
        exit;
      end;
  end;


begin
  result := TSemanticVersion.Empty;
  sValue := Trim(version);
  len := Length(sValue);
  currentElement := '';
  i := 1;
  count := 0;

  //iterate the numeric elements
  for e := 0 to 2 do
  begin
    currentElement := '';
    while i <= len do
    begin
      if TSemanticVersion.IsDigit(sValue[i]) then
      begin
        currentElement := currentElement + sValue[i];
        Inc(i);
      end
      else
      begin
        if not CharInSet(sValue[i], ['.', '-', '+']) then
          currentElement := currentElement + sValue[i];
        break;
      end;

    end;
    if currentElement <> '' then
    begin
      if not IsDecimalInteger(currentElement) then
        raise EArgumentException.Create('Not a valid version string - [' + currentElement + '] is not an integer');
      Result.FElements[e] := StrToInt(currentElement);
      Inc(count);
    end;
    //don't skip the . if we are parsing the last valid element
    if (e < 2) and (i <= len) and (sValue[i] = '.') then
      Inc(i);
  end;
  if i < len then
  begin
    case sValue[i] of
      '-' : //a Tag follows
      begin
        ParseTag;
      end;
      '+' : //everything that follows is metadata
      begin
        ParseMetaData;
      end;
    else
      raise EArgumentException.Create('Not a valid version string, invalid char at position : [' + IntToStr(i) + '] ''' + sValue[i] + '''');
    end;
  end;

  if count < 2 then
    raise EArgumentException.Create('Not a valid version string - needs at least two parts, e.g: 1.0');


end;

function TSemanticVersion.ToString: string;
begin
  if IsEmpty then
    Exit('');

  if FPreReleaseTag = '' then
    result := Format('%d.%d.%d',[Major, Minor, Patch])
  else
    result := Format('%d.%d.%d-%s',[Major, Minor, Patch,FPreReleaseTag]);
  if FMetaData <> '' then
    result := result + '+' + FMetaData;
end;

function TSemanticVersion.ToStringNoMeta: string;
begin
  if IsEmpty then
    Exit('');

  if FPreReleaseTag = '' then
    result := Format('%d.%d.%d',[Major, Minor, Patch])
  else
    result := Format('%d.%d.%d-%s',[Major, Minor, Patch,FPreReleaseTag]);
end;

class function TSemanticVersion.TryParseWithError(const version: string; out value: TSemanticVersion; out error: string): boolean;
begin
  result := true;
  try
    value := Parse(version);
  except
    on e : Exception do
    begin
      result := False;
      error := e.Message;
    end;
  end;
end;

class function TSemanticVersion.TryParse(const version: string; out value: TSemanticVersion): boolean;
begin
  result := true;
  try
    value := Parse(version);
  except
    result := False;
  end;
end;

constructor TSemanticVersion.Create(const major, minor: Cardinal; const preReleaseTag: string);
begin
  Create(major,minor,0,preReleaseTag,'');
end;

constructor TSemanticVersion.Create(const major, minor, patch: Cardinal; const preReleaseTag, metaData: string);
begin
  FElements[0] := major;
  FElements[1] := minor;
  FElements[2] := patch;
  FPreReleaseTag      := preReleaseTag;
  FMetaData   := metaData;
end;


end.
