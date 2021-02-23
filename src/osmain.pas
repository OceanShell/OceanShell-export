unit osmain;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Variants, Classes, Graphics, Controls, Forms, ComCtrls, LCLType,
  Menus, Dialogs, ActnList, StdCtrls, IniFiles, ExtCtrls, DateUtils, sqldb, DB,
  Buttons, DBGrids, Spin, DBCtrls, DateTimePicker, dynlibs, LCLIntf, ComboEx,
  FileCtrl;

type
   MapDS=record
     ID:int64;
     Cruise_ID:int64;
     Latitude:real;
     Longitude:real;
     x:int64;
     y:int64;
end;

type
  {$IFDEF CPU386}
    PtrUInt = DWORD;
    PtrInt = longint;
  {$ENDIF}
  {$IFDEF CPUX64}
    PtrUInt = QWORD;
    PtrInt = int64;
  {$ENDIF}

  { Tfrmosmain }

  Tfrmosmain = class(TForm)
    btnExport: TBitBtn;
    btnMap: TBitBtn;
    btnSelect: TBitBtn;
    cbInstitute: TComboBox;
    cbCruise: TComboBox;
    cbProject: TComboBox;
    cbPlatform: TComboBox;
    cbPredefinedRegion: TComboBox;
    cbCountry: TComboBox;
    chkNOTCountry: TCheckBox;
    chkNOTInstitute: TCheckBox;
    chkNOTCruise: TCheckBox;
    chkNOTPlatform: TCheckBox;
    chkNOTProject: TCheckBox;
    chkNOTSource: TCheckBox;
    chkPeriod: TCheckBox;
    cbSource: TComboBox;
    dtpDateMax: TDateTimePicker;
    dtpDateMin: TDateTimePicker;
    gbAuxiliaryParameters: TGroupBox;
    gbDateandTime: TGroupBox;
    gbRegion: TGroupBox;
    Label1: TLabel;
    lbResetSearchStations: TLabel;
    iMeteo: TMenuItem;
    btnExportASCII: TMenuItem;
    btnExportHDB: TMenuItem;
    btnExportNetCDF: TMenuItem;
    Panel1: TPanel;
    pcRegion: TPageControl;
    ODir: TSelectDirectoryDialog;
    pmExport: TPopupMenu;
    sbDatabase: TStatusBar;
    sbSelection: TStatusBar;
    OD: TOpenDialog;
    SD: TSaveDialog;
    ListBox1: TListBox;
    seLatMax: TFloatSpinEdit;
    seLatMin: TFloatSpinEdit;
    seLonMax: TFloatSpinEdit;
    seLonMin: TFloatSpinEdit;
    TabSheet1: TTabSheet;
    TabSheet3: TTabSheet;

    procedure btnExportClick(Sender: TObject);
    procedure cbCruiseDropDown(Sender: TObject);
    procedure cbProjectDropDown(Sender: TObject);
    procedure cbPlatformSelect(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbResetSearchStationsClick(Sender: TObject);
    procedure btnMapClick(Sender: TObject);
    procedure btnSelectClick(Sender: TObject);
    procedure cbCountryDropDown(Sender: TObject);
    procedure cbInstituteDropDown(Sender: TObject);
    procedure cbPlatformDropDown(Sender: TObject);
    procedure cbPredefinedRegionDropDown(Sender: TObject);
    procedure cbSourceDropDown(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);

  private
    procedure DatabaseInfo;
    procedure SaveSettingsStationSearch;

  public
    procedure SelectionInfo;
    procedure CDSNavigation;
    procedure PopulateTblList;
  end;

const
  StationSQL =
    'SELECT '+
    'STATION.ID, LATITUDE, LONGITUDE, DATEANDTIME, BOTTOMDEPTH, LASTLEVEL_M, '+
    'LASTLEVEL_DBAR, CRUISE_ID, CAST_NUMBER, ST_NUMBER_ORIGIN, '+
    'QCFLAG, BOTTOMDEPTH_GEBCO, STVERSION  '+
    'FROM STATION, CRUISE, PLATFORM, COUNTRY, INSTITUTE, PROJECT, SOURCE WHERE '+
    'STATION.CRUISE_ID=CRUISE.ID AND CRUISE.PLATFORM_ID=PLATFORM.ID AND '+
    'PLATFORM.COUNTRY_ID=COUNTRY.ID AND CRUISE.INSTITUTE_ID=INSTITUTE.ID AND '+
    'CRUISE.PROJECT_ID=PROJECT.ID AND CRUISE.SOURCE_ID=SOURCE.ID ';

var
  frmosmain: Tfrmosmain;

  IniFileName:string;
  GlobalPath:string; //global paths for the app
  CurrentParTable: string;

  depth_units: integer; //0-meters, 1-dBar }

  StationIDMin, StationIDMax: integer;
  StationLatMin,StationLatMax,StationLonMin,StationLonMax: real;
  SLatMin,SLatMax,SLonMin,SLonMax:Real;
  StationDateMin, StationDateMax, SDateMin, SDateMax :TDateTime;
  StationDateAddedMin, StationDateAddedMax, StationDateUpdatedMin, StationDateUpdatedMax :TDateTime;
  StationCount, SCount:Integer; //number OD stations in database and selection

  CRUISEInfoObtained: boolean = false; //getting CRUISE info on app start
  NavigationOrder:boolean=true; //Stop navigation until all modules responded

  libgswteos, netcdf:TLibHandle;
  libgswteos_exists, netcdf_exists:boolean;

  Length_arr:integer;
  MapDataset: array of MapDS;

  frmmap_open :boolean;

const
   NC_NOWRITE   = 0;    // file for reading
   NC_WRITE     = 1;    // file for writing
   NC_GLOBAL    = -1;   // global attributes ID
   NC_MAX_NAME  = 1024; // value from netcdf.h
   NC_UNLIMITED = 0;
   WS_EX_STATICEDGE = $20000;
   buf_len      = 3000;

   S_clr:Array[1..15] of TColor =
   (clBlue,clFuchsia,clMaroon,clBlack,clGreen,clNavy,clPurple,clTeal,
    clOlive,clGray,clSilver,clLime,clYellow,clAqua,clLtGray);

implementation


uses
(* core modules *)
  dm,
  ArbytraryRegion,

(* data export *)
  osexport,

(* tools *)
  osmap
;

{$R *.lfm}


procedure Tfrmosmain.FormCreate(Sender: TObject);
Var
  Ini: TIniFile;
  server, DBPath, DBHost, DBUser, DBPass:string;
begin

 (* Defining Global Path - application root lolder *)
  GlobalPath:=ExtractFilePath(Application.ExeName);

  if not FileExists(GlobalPath+'database.ini') then
    if MessageDlg('Please, put database.ini next to the program',
       mtWarning, [mbOk], 0)=MrOk then exit;

  server:='firebird';

  Ini := TIniFile.Create(GlobalPath+'database.ini');
  try
    DBUser :=Ini.ReadString(server, 'user',     'SYSDBA');
    DBPass :=Ini.ReadString(server, 'pass',     'masterkey');
    DBHost :=Ini.ReadString(server, 'host',     'localhost');
    DBPath :=Ini.ReadString(server, 'dbpath',   '');
  finally
    Ini.Free;
  end;

  with frmdm.DBLoader do begin
    {$IFDEF WINDOWS}
      LibraryName:=GlobalPath+'fbclient.dll';
    {$ENDIF}
    {$IFDEF LINUX}
      LibraryName:=GlobalPath+'libfbclient.so.3.0.5';
    {$ENDIF}
    {$IFDEF DARWIN}
      LibraryName:=GlobalPath+'libfbclient.dylib';
    {$ENDIF}
    Enabled:=true;
  end;

  try
    with frmdm.IBDB do begin
      Params.Clear;
      Connected:=false;
      UserName:=DBUser;
      Password:=DBPass;
      HostName:=DBHost;
      DatabaseName:=DBPath;
      Params.Add('WireCompression=true');
      Connected:=true;
    end;
    caption:='Export ['+DBHost+': '+DBPath+']';
  except
    on e: Exception do
      if MessageDlg(e.message, mtError, [mbOk], 0)=mrOk then close;
  end;
end;


procedure Tfrmosmain.FormShow(Sender: TObject);
Var
  Ini:TIniFile;
begin

(* flags on open forms *)
 frmmap_open:=false;

  (* Define settings file, unique for every user*)
  IniFileName:=GetUserDir+'.climateshell';
  if not FileExists(IniFileName) then begin
    Ini:=TIniFile.Create(IniFileName);
    Ini.WriteInteger('main', 'Language', 0);
    Ini.Free;
  end;

  (* Loading TEOS-2010 dynamic library *)
  {$IFDEF WINDOWS}
    libgswteos:=LoadLibrary(PChar(GlobalPath+'libgswteos-10.dll'));
   // netcdf    :=LoadLibrary(PChar(GlobalPath+'netcdf.dll'));
  {$ENDIF}
  {$IFDEF LINUX}
    libgswteos:=LoadLibrary(PChar(GlobalPath+'libgswteos-10.so'));
   // netcdf    :=LoadLibrary(PChar(GlobalPath+'libnetcdf.so'));
  {$ENDIF}
  {$IFDEF DARWIN}
    libgswteos:=LoadLibrary(PChar(GlobalPath+'libgswteos-10.dylib'));
   // netcdf    :=LoadLibrary(PChar(GlobalPath+'libnetcdf.dylib'));
  {$ENDIF}


  //GibbsSeaWater loaded?
  if libgswteos=0 then libgswteos_exists:=false else libgswteos_exists:=true;
    if not libgswteos_exists then showmessage('TEOS-10 is not installed');

 { //netCDF loaded?
  if netcdf=0 then netcdf_exists:=false else netcdf_exists:=true;

  if not netcdf_exists then showmessage('netCDF is not installed'); }


  (* Define global delimiter *)
  DefaultFormatSettings.DecimalSeparator := '.';

  (* Loading settings from INI file *)
  Ini := TIniFile.Create(IniFileName);
  try
    (* main form sizes *)
    Top   :=Ini.ReadInteger( 'osmain', 'top',    50);
    Left  :=Ini.ReadInteger( 'osmain', 'left',   50);
    Width :=Ini.ReadInteger( 'osmain', 'width',  900);
    Height:=Ini.ReadInteger( 'osmain', 'weight', 500);

    (* STATION search settings *)
    pcRegion.ActivePageIndex:=Ini.ReadInteger( 'osmain', 'station_region_pcRegion', 0);
    seLatMin.Value   :=Ini.ReadFloat  ( 'osmain', 'station_latmin',     0);
    seLatMax.Value   :=Ini.ReadFloat  ( 'osmain', 'station_latmax',     0);
    seLonMin.Value   :=Ini.ReadFloat  ( 'osmain', 'station_lonmin',     0);
    seLonMax.Value   :=Ini.ReadFloat  ( 'osmain', 'station_lonmax',     0);
    chkPeriod.Checked:=Ini.ReadBool   ( 'osmain', 'station_period', false);
    cbPlatform.Text  :=Ini.ReadString ( 'osmain', 'station_platform',  '');
    cbCountry.Text   :=Ini.ReadString ( 'osmain', 'station_country',   '');
    cbSource.Text    :=Ini.ReadString ( 'osmain', 'station_source',    '');
    cbCruise.Text    :=Ini.ReadString ( 'osmain', 'station_cruise',    '');
    cbInstitute.Text :=Ini.ReadString ( 'osmain', 'station_institute', '');
    cbProject.Text   :=Ini.ReadString ( 'osmain', 'station_project',   '');
    dtpDateMin.DateTime:=Ini.ReadDateTime('osmain', 'station_datemin', now);
    dtpDateMax.DateTime:=Ini.ReadDateTime('osmain', 'station_datemax', now);
  finally
    Ini.Free;
  end;

  if cbCruise.Text<>'' then cbCruise.Enabled:=true;

  DatabaseInfo;
end;


procedure Tfrmosmain.btnSelectClick(Sender: TObject);
var
i, k, fl:integer;
SSYearMin,SSYearMax,SSMonthMin,SSMonthMax,SSDayMin,SSDayMax :Word;
NotCondCountry, NotCondPlatform, NotCondSource, NotCondCruise:string;
NotCondInstitute, NotCondProject, NotCondOrigin, SBordersFile:string;

dlat, dlon, lat, lon, dist:real;
time0, time1:TDateTime;
buf_str, SQL_str, QCFlag_str, cr: string;
LatMin, LatMax, LonMin, LonMax:real;
begin

(* saving current search settings *)
SaveSettingsStationSearch;

frmosmain.Enabled:=false;
btnSelect.Enabled:=false;
Application.ProcessMessages;

try
// frmdm.Q.DisableControls;
 DecodeDate(dtpDateMin.Date, SSYearMin, SSMonthMin, SSDayMin);
 DecodeDate(dtpDateMax.Date, SSYearMax, SSMonthMax, SSDayMax);

  if chkNOTCountry.Checked   =true then NotCondCountry   :='NOT' else NotCondCountry   :='';
  if chkNOTPlatform.Checked  =true then NotCondPlatform  :='NOT' else NotCondPlatform  :='';
  if chkNOTSource.Checked    =true then NotCondSource    :='NOT' else NotCondSource    :='';
  if chkNOTCruise.Checked    =true then NotCondCruise    :='NOT' else NotCondCruise    :='';
  if chkNOTInstitute.Checked =true then NotCondInstitute :='NOT' else NotCondInstitute :='';
  if chkNOTProject.Checked   =true then NotCondProject   :='NOT' else NotCondProject   :='';

  SQL_str:='';


  SQL_str:=SQL_str+' AND (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) ';

  if pcRegion.ActivePageIndex=0 then begin
    SQL_str:=SQL_str+' AND (LATITUDE BETWEEN '+seLatMin.Text+
                     ' AND '+seLatMax.Text+') ';

     if seLonMax.Value>=seLonMin.Value then
       SQL_str:=SQL_str+' AND (LONGITUDE BETWEEN '+seLonMin.Text+
                        ' AND '+seLonMax.Text+') ';

     if seLonMax.Value<seLonMin.Value then
      SQL_str:=SQL_str+' AND ((LONGITUDE>='+seLonMin.Text+
                       ' AND LONGITUDE<=180) OR '+
                       '(LONGITUDE>=-180 and LONGITUDE<='+seLonMax.Text+')) ';
    end;


    (* Date and Time *)
    // From date to date
  //  if (dtpDateMin.DateTime<>MinDate) or (dtpDateMax.DateTime<>MaxDate) then begin
      if chkPeriod.Checked=false then begin
       SQL_str:=SQL_str+' AND (DATEANDTIME BETWEEN '+
                        QuotedStr(DateToStr(dtpDateMin.DateTime))+' AND '+
                        QuotedStr(DateToStr(dtpDateMax.DateTime))+') ';
      end;

     //Date in Period
     if chkPeriod.Checked=true then begin
      SQL_str:=SQL_str+' AND (Extract(Year from DATEANDTIME) BETWEEN '+
                       IntToStr(SSYearMin)+' AND '+
                       IntToStr(SSYearMax)+') ';

      if SSMonthMin<=SSMonthMax then
         SQL_str:=SQL_str+' AND (Extract(Month from DATEANDTIME) BETWEEN '+
                          IntToStr(SSMonthMin)+' AND '+
                          IntToStr(SSMonthMax)+') ';
      if SSMonthMin>SSMonthMax then
         SQL_str:=SQL_str+' AND ((Extract(Month from DATEANDTIME)>= '+
                          IntToStr(SSMonthMin)+') OR'+
                          ' (Extract(Month from DATEANDTIME)<= '+
                          IntToStr(SSMonthMax)+')) ';
      if SSDayMin<=SSDayMax then
         SQL_str:=SQL_str+' AND (Extract(Day from DATEANDTIME) BETWEEN '+
                          IntToStr(SSDayMin)+' AND '+
                          IntToStr(SSDayMax)+') ';
      if SSDayMin>SSDayMax then
         SQL_str:=SQL_str+' AND ((Extract(Day from DATEANDTIME)>= '+
                          IntToStr(SSDayMin)+') OR '+
                          ' (Extract(Day from DATEANDTIME)<= '+
                          IntToStr(SSDayMax)+')) ';
    end;
  //  end; // dates are not default


    // if there's a cruise
    if trim(cbCruise.Text)<>'' then begin
     if Pos('_', cbCruise.Text)>0 then
        cr:=copy(cbCruise.Text, 1, Pos('_', cbCruise.Text)-1) else
        cr:=cbCruise.Text;
     SQL_str:=SQL_str+' AND ('+NotCondCruise+' CRUISE.ID = '+cr+') ';
    end;

    //if there's a platform but no cruise
    if (trim(cbPlatform.Text)<>'') and (trim(cbCruise.Text)='') then
     SQL_str:=SQL_str+' AND ('+NotCondPlatform+' PLATFORM.NAME = '+QuotedStr(cbPlatform.Text)+') ' else

    //if there's a country, but no cruise/platform
    if (trim(cbCountry.Text)<>'') and (trim(cbPlatform.Text)='') and (trim(cbCruise.Text)='') then
     SQL_str:=SQL_str+' AND ('+NotCondCountry+' COUNTRY.NAME = '+QuotedStr(cbCountry.Text)+') ';

    //if there's a source but no cruise
    if (trim(cbSource.Text)<>'') and (trim(cbCruise.Text)='') then
     SQL_str:=SQL_str+' AND ('+NotCondSource+' SOURCE.NAME = '+QuotedStr(cbSource.Text)+') ';

  {
    if trim(cbSource.Text)<>'' then begin
     SQL_str:=SQL_str+' AND (STATION.CRUISE_ID IN (SELECT CRUISE.ID FROM '+
          ' CRUISE, SOURCE WHERE CRUISE.SOURCE_ID=SOURCE.ID AND '+
          NotCondSource+' SOURCE.NAME = '+QuotedStr(cbSource.Text)+')) ';
    end;

    if trim(cbPlatform.Text)<>'' then begin
      SQL_str:=SQL_str+' AND (STATION.CRUISE_ID IN (SELECT CRUISE.ID FROM '+
      ' CRUISE, PLATFORM WHERE CRUISE.PLATFORM_ID=PLATFORM.ID AND '+
      NotCondSource+' PLATFORM.NAME = '+QuotedStr(cbPlatform.Text)+')) ';
    end;

    if trim(cbCountry.Text)<>'' then begin
      SQL_str:=SQL_str+' AND (STATION.CRUISE_ID IN (SELECT CRUISE.ID FROM '+
      ' CRUISE, PLATFORM, COUNTRY WHERE CRUISE.PLATFORM_ID=PLATFORM.ID AND '+
      ' PLATFORM.COUNTRY_ID=COUNTRY.ID AND '+NotCondSource+
      ' COUNTRY.NAME = '+QuotedStr(cbCountry.Text)+')) ';
    end;

    if trim(cbCruise.Text)<>'' then begin
     if Pos('_', cbCruise.Text)>0 then
        cr:=copy(cbCruise.Text, 1, Pos('_', cbCruise.Text)-1) else
        cr:=cbCruise.Text;
     SQL_str:=SQL_str+' AND (STATION.CRUISE_ID IN (SELECT CRUISE.ID FROM '+
     ' CRUISE WHERE '+NotCondSource+' CRUISE.ID = '+cr+')) ';
    end; }

    if trim(cbInstitute.Text)<>'' then begin
     SQL_str:=SQL_str+' AND ('+NotCondSource+' INSTITUTE.NAME = '+QuotedStr(cbInstitute.Text)+') ';
    end;

    if trim(cbProject.Text)<>'' then begin
     SQL_str:=SQL_str+' AND ('+NotCondSource+' PROJECT.NAME = '+QuotedStr(cbProject.Text)+') ';
    end;

    SQL_str:=SQL_str+' AND (STATION.DUPLICATE=FALSE) ';

  //  if copy(SQL_str, 1, 4)=' AND'   then SQL_str:=Copy(SQL_str, 5, length(SQL_str));


    // predefined region
    if pcRegion.ActivePageIndex=1 then begin

       if cbPredefinedRegion.ItemIndex<0 then
        if MessageDlg('Choose a region first', mtWarning, [mbOk], 0)=mrOk then exit;

      ArbytraryRegion.GetArbirtaryRegion(
      GlobalPath+'support'+PathDelim+'sea_borders'+PathDelim+
      cbPredefinedRegion.Text+'.bln',
      LatMin, LatMax, LonMin, LonMax);

      with frmdm.q1 do begin
       Close;
         SQL.Clear;
         SQL.Add(' DELETE FROM TEMPORARY_ID_LIST ');
       ExecSQL;
      end;
      frmdm.TR.CommitRetaining;

      with frmdm.q1 do begin
       Close;
         SQL.Clear;
         SQL.Add(' SELECT ID, LATITUDE, LONGITUDE FROM STATION ');
         SQL.Add(' WHERE ');
         SQL.Add(' (LATITUDE BETWEEN ' );
         SQL.Add(floattostr(LatMin)+' AND ');
         SQL.Add(floattostr(LatMax)+') AND ');
         if LonMax<=180 then begin
           SQL.Add(' (LONGITUDE BETWEEN ');
           SQL.Add(floattostr(LonMin)+' AND ');
           SQL.Add(floattostr(LonMax)+') ');
         end;
         if LonMax>180 then begin
           SQL.Add(' ((LONGITUDE>= ');
           SQL.Add(floattostr(LonMin));
           SQL.Add(' AND LONGITUDE<=180) OR ');
           SQL.Add('(LONGITUDE>=-180 and LONGITUDE<= ');
           SQL.Add(floattostr(LonMax)+')) ');
         end;
         SQL.Add(' AND '+SQL_str);
      // showmessage(frmdm.q1.SQL.Text);
       Open;
      end;

    //  showmessage(inttostr(frmdm.q1.RecordCount));

      while not frmdm.q1.EOF do begin
         Lat:=frmdm.q1.FieldByName('LATITUDE').Value;
         Lon:=frmdm.q1.FieldByName('LONGITUDE').Value;

         if (Odd(Point_Status(Lon,Lat))) then begin
         // memo2.lines.add(floattostr(lat)+'   '+floattostr(lon));
          with frmdm.q2 do begin
           Close;
            SQL.Clear;
            SQL.Add(' INSERT INTO TEMPORARY_ID_LIST ');
            SQL.Add(' (ID) VALUES (:ID) ');
            ParamByName('ID').Value:=frmdm.q1.FieldByName('ID').Value;
           ExecSQL;
          end;
         end;
       frmdm.q1.Next;
      end;
      frmdm.TR.CommitRetaining;
      SQL_str:=' STATION.ID IN (SELECT ID FROM TEMPORARY_ID_LIST) ';
    end;

   if frmdm.TR.Active=true then frmdm.TR.Commit;
   with frmdm.Q do begin
    Close;
     SQL.Clear;
     SQL.Add(StationSQL);
     if trim(SQL_str)<>'' then begin
     // SQL.Add(' WHERE ');
      SQL.Add(SQL_str);
     end;
     SQL.Add('ORDER BY DATEANDTIME ');

     (* Show the query before executing *)
  {  if MessageDlg(SQL.Text+#13+#13+'Execute the query?',
                  mtInformation, [mbYes, mbNo],0)=mrNo then exit; }

   // memo1.lines.Add(SQL.Text);
    Open;
   end;


   SelectionInfo;
   CDSNavigation;

finally
  frmosmain.Enabled:=true;
  btnSelect.Enabled:=true;
  Application.ProcessMessages;
end;
end;


procedure Tfrmosmain.lbResetSearchStationsClick(Sender: TObject);
begin
  pcRegion.ActivePageIndex:=0;

  cbPredefinedRegion.Items.Clear;

  seLatMin.Value:=StationLatMin;
  seLatMax.Value:=StationLatMax;
  seLonMin.Value:=StationLonMin;
  seLonMax.Value:=StationLonMax;

  cbPlatform.Clear;
  cbCountry.Clear;
  cbSource.Clear;
  cbCruise.Clear;
  cbInstitute.Clear;
  cbProject.Clear;

  cbCruise.Enabled:=false;

  chkNOTPlatform.Checked:=false;
  chkNOTCountry.Checked:=false;
  chkNOTSource.Checked:=false;
  chkNOTCruise.Checked:=false;
  chkNOTInstitute.Checked:=false;
  chkNOTProject.Checked:=false;

  dtpDateMin.DateTime:=StationDateMin;
  dtpDateMax.DateTime:=StationDateMax;
  chkPeriod.Checked:=false;
end;


(* gathering info about the database *)
procedure Tfrmosmain.DatabaseInfo;
var
  TRt_DB1:TSQLTransaction;
  Qt_DB1:TSQLQuery;
  k:integer;
begin

(* temporary transaction for main database *)
TRt_DB1:=TSQLTransaction.Create(self);
TRt_DB1.DataBase:=frmdm.IBDB;

(* temporary query for main database *)
Qt_DB1 :=TSQLQuery.Create(self);
Qt_DB1.Database:=frmdm.IBDB;
Qt_DB1.Transaction:=TRt_DB1;
 try
   with Qt_DB1 do begin
    Close;
        SQL.Clear;
        SQL.Add(' select count(ID) as StCount, ');
        SQL.Add(' min(LATITUDE) as StLatMin, max(LATITUDE) as StLatMax, ');
        SQL.Add(' min(LONGITUDE) as StLonMin, max(LONGITUDE) as StLonMax, ');
        SQL.Add(' min(DATEANDTIME) as StDateMin, ');
        SQL.Add(' max(DATEANDTIME) as StDateMax ');
        SQL.Add(' from STATION');
    Open;
      StationCount:=FieldByName('StCount').AsInteger;
       if StationCount>0 then begin
         StationLatMin  :=FieldByName('StLatMin').AsFloat;
         StationLatMax  :=FieldByName('StLatMax').AsFloat;
         StationLonMin  :=FieldByName('StLonMin').AsFloat;
         StationLonMax  :=FieldByName('StLonMax').AsFloat;
         StationDateMin :=FieldByName('StDateMin').AsDateTime;
         StationDateMax :=FieldByName('StDateMax').AsDateTime;

       with sbDatabase do begin
         Panels[1].Text:='LtMin: '+floattostr(StationLatMin);
         Panels[2].Text:='LtMax: '+floattostr(StationLatMax);
         Panels[3].Text:='LnMin: '+floattostr(StationLonMin);
         Panels[4].Text:='LnMax: '+floattostr(StationLonMax);
         Panels[5].Text:='DateMin: '+datetostr(StationDateMin);
         Panels[6].Text:='DateMax: '+datetostr(StationDateMax);
         Panels[7].Text:='Stations: '+inttostr(StationCount);
       end;

       if (selatmin.Value=0) and (selatmax.Value=0) then begin
           seLatMin.Value:=StationLatMin;
           seLatMax.Value:=StationLatMax;
           seLonMin.Value:=StationLonMin;
           seLonMax.Value:=StationLonMax;

           dtpDateMin.DateTime:=StationDateMin;
           dtpDateMax.DateTime:=StationDateMax;
       end;
      end;
    Close;
   end;

   (* permanent list for parameter tables *)
   PopulateTblList;

 Finally
  TRt_DB1.Commit;
  Qt_DB1.Free;
  TRt_DB1.free;
 end;
end;


(* gathering info about selected stations *)
procedure Tfrmosmain.SelectionInfo;
var
  k: integer;
  lat1, lon1:real;
  dat1:TDateTime;
  items_enabled:boolean;
  yy, mn, dd:word;
begin

 try
  frmdm.Q.DisableControls;

  SLatMin:=90;  SLatMax:=-90;
  SLonMin:=180; SLonMax:=-180;
  SDateMin:=Now;
  yy:=1; mn:=1; dd:=1;
  SDateMax:=EncodeDate(yy, mn, dd);


  SetLength(MapDataset, StationCount);
  frmdm.Q.First;
  k:=-1;
  while not frmdm.Q.EOF do begin
   inc(k);
   lat1:=frmdm.Q.FieldByName('LATITUDE').AsFloat;
   lon1:=frmdm.Q.FieldByName('LONGITUDE').AsFloat;
   dat1:=frmdm.Q.FieldByName('DATEANDTIME').AsDateTime;

     if lat1<SLatMin then SLatMin:=lat1;
     if lat1>SLatMax then SLatMax:=lat1;
     if lon1<SLonMin then SLonMin:=lon1;
     if lon1>SLonMax then SLonMax:=lon1;
     if CompareDate(dat1, SDateMin)<0 then SDateMin:=dat1;
     if CompareDate(dat1, SDateMax)>0 then SDateMax:=dat1;

     MapDataset[k].ID:=frmdm.Q.FieldByName('ID').Value;
     MapDataset[k].Cruise_ID:=frmdm.Q.FieldByName('CRUISE_ID').Value;
     MapDataset[k].Latitude :=lat1;
     MapDataset[k].Longitude:=lon1;

    frmdm.Q.Next;
  end;
  frmdm.Q.First;

  SCount:=frmdm.Q.RecordCount;
  SetLength(MapDataset, SCount+1);

     if SCount>0 then begin
       with sbSelection do begin
         Panels[1].Text:='LtMin: '+floattostr(SLatMin);
         Panels[2].Text:='LtMax: '+floattostr(SLatMax);
         Panels[3].Text:='LnMin: '+floattostr(SLonMin);
         Panels[4].Text:='LnMax: '+floattostr(SLonMax);
         Panels[5].Text:='DateMin: '+datetostr(SDateMin);
         Panels[6].Text:='DateMax: '+datetostr(SDateMax);
         Panels[7].Text:='Stations: '+inttostr(SCount);
       end;
     end else for k:=1 to 7 do sbSelection.Panels[k].Text:='---';

  (* if there are selected station enabling some menu items *)
  if SCount>0 then items_enabled:=true else items_enabled:=false;

  btnMap.Enabled:=items_enabled;
  btnExport.Enabled:=items_enabled;

  finally
     frmdm.Q.EnableControls;
  end;
end;


procedure Tfrmosmain.cbPredefinedRegionDropDown(Sender: TObject);
Var
  fdb:TSearchRec;
  fname: string;
begin
fdb.Name:='';
cbPredefinedRegion.Clear;
 FindFirst(GlobalPath+'support'+PathDelim+'sea_borders'+PathDelim+'*.bln',faAnyFile, fdb);
  if fdb.Name<>'' then begin
   fname:=ExtractFileName(fdb.Name);
    cbPredefinedRegion.Items.Add(copy(fname,1, length(fname)-4));
     while findnext(fdb)=0 do begin
       fname:=ExtractFileName(fdb.Name);
       cbPredefinedRegion.Items.Add(copy(fname,1, length(fname)-4));
     end;
  end;
 FindClose(fdb);
end;

procedure Tfrmosmain.cbPlatformDropDown(Sender: TObject);
Var
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
  pp, k: integer;
  SQL_str:string;
begin
  try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;

   cbPlatform.Clear;
   if (cbSource.Text='') and (cbCountry.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT PLATFORM.NAME FROM ');
       SQL.Add(' PLATFORM, CRUISE, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) ');
      { SQL.Add(' RIGHT JOIN CRUISE ON ');
       SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID '); }
       SQL.Add(' ORDER BY PLATFORM.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text<>'') and (cbCountry.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT PLATFORM.NAME FROM ');
       SQL.Add(' PLATFORM, CRUISE, SOURCE, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (SOURCE.NAME='+QuotedStr(cbSource.Text)+') ');
       SQL.Add(' ORDER BY PLATFORM.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text='') and (cbCountry.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT PLATFORM.NAME FROM PLATFORM ');
       SQL.Add(' PLATFORM, CRUISE, SOURCE, COUNTRY, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (PLATFORM.COUNTRY_ID=COUNTRY.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (COUNTRY.NAME='+QuotedStr(cbCountry.Text)+') ');
       SQL.Add(' ORDER BY PLATFORM.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text<>'') and (cbCountry.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT PLATFORM.NAME FROM PLATFORM ');
       SQL.Add(' PLATFORM, CRUISE, SOURCE, COUNTRY, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (PLATFORM.COUNTRY_ID=COUNTRY.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (COUNTRY.NAME='+QuotedStr(cbCountry.Text)+') AND ');
       SQL.Add(' (SOURCE.NAME='+QuotedStr(cbSource.Text)+') ');
       SQL.Add(' ORDER BY PLATFORM.NAME ');
     Open;
    end;
   end;

   while not Qt.Eof do begin
     cbPlatform.Items.Add(Qt.Fields[0].AsString);
    Qt.Next;
   end;

    Qt.Close;
    TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;

  cbCruise.Clear;
end;


procedure Tfrmosmain.cbCruiseDropDown(Sender: TObject);
Var
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
  pp, k, cr_id: integer;
  SQL_str, cr, cr_num:string;
begin
  try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;

    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT CRUISE.ID, CRUISE_NUMBER ');
       SQL.Add(' FROM CRUISE, STATION, PLATFORM ');
       SQL.Add(' WHERE ');
       SQL.ADD(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (PLATFORM.NAME = '+QuotedStr(cbPlatform.Text)+') ');
       SQL.Add(' ORDER BY CRUISE_NUMBER ');
     //  showmessage(SQL.Text);
     Qt.Open;
    end;

    cbCruise.Clear;
   while not Qt.Eof do begin
     cr_id:=Qt.Fields[0].Value;
     cr_num:=Qt.Fields[1].AsString;
     if trim(cr_num)<>'' then
        cr:=inttostr(cr_id)+'_'+cr_num else
        cr:=inttostr(cr_id);
     cbCruise.Items.Add(cr);
    Qt.Next;
   end;

    Qt.Close;
    TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;
end;

procedure Tfrmosmain.cbPlatformSelect(Sender: TObject);
begin
  if cbPlatform.Text<>'' then cbCruise.Enabled:=true;
end;


procedure Tfrmosmain.cbCountryDropDown(Sender: TObject);
Var
  pp:integer;
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
begin

  try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;


   cbCountry.Clear;
   if (cbSource.Text='') and (cbPLATFORM.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT COUNTRY.NAME FROM ');
       SQL.Add(' COUNTRY, CRUISE, STATION, PLATFORM ');
       SQL.Add(' WHERE ');
       SQL.Add(' (PLATFORM.COUNTRY_ID=COUNTRY.ID) AND ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) ');
      { SQL.Add(' RIGHT JOIN CRUISE ON ');
       SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID '); }
       SQL.Add(' ORDER BY COUNTRY.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text<>'') and (cbPlatform.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT COUNTRY.NAME FROM ');
       SQL.Add(' COUNTRY, PLATFORM, CRUISE, SOURCE, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (COUNTRY.ID=PLATFORM.COUNTRY_ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (SOURCE.NAME='+QuotedStr(cbSource.Text)+') ');
       SQL.Add(' ORDER BY COUNTRY.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text='') and (cbPlatform.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT COUNTRY.NAME FROM ');
       SQL.Add(' COUNTRY, PLATFORM, CRUISE, SOURCE, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (COUNTRY.ID=PLATFORM.COUNTRY_ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (PLATFORM.NAME='+QuotedStr(cbPlatform.Text)+') ');
       SQL.Add(' ORDER BY COUNTRY.NAME ');
     Open;
    end;
   end;

   if (cbSource.Text<>'') and (cbPlatform.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT COUNTRY.NAME FROM ');
       SQL.Add(' COUNTRY, PLATFORM, CRUISE, SOURCE, STATION WHERE ');
       SQL.Add(' (CRUISE.PLATFORM_ID=PLATFORM.ID) AND ');
       SQL.Add(' (COUNTRY.ID=PLATFORM.COUNTRY_ID) AND ');
       SQL.Add(' (CRUISE.SOURCE_ID=SOURCE.ID) AND ');
       SQL.Add(' (STATION.CRUISE_ID=CRUISE.ID) AND ');
       SQL.Add(' (STATION.QCFLAG=0 OR STATION.QCFLAG>=3) AND ');
       SQL.Add(' (CRUISE.STATIONS_DATABASE>0) AND ');
       SQL.Add(' (CRUISE.DUPLICATE = FALSE) AND ');
       SQL.Add(' (SOURCE.NAME='+QuotedStr(cbSource.Text)+') AND ');
       SQL.Add(' (PLATFORM.NAME='+QuotedStr(cbPlatform.Text)+') ');
       SQL.Add(' ORDER BY COUNTRY.NAME ');
     Open;
    end;
   end;

   while not Qt.Eof do begin
     cbCountry.Items.Add(Qt.Fields[0].AsString);
    Qt.Next;
   end;

//   DBCruiseCountry.Items:=cbCountry.Items;

   Qt.Close;
   TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;
end;

procedure Tfrmosmain.cbSourceDropDown(Sender: TObject);
Var
  pp:integer;
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
begin

  try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;

   cbSource.Clear;

   if (cbCountry.Text='') and (cbPLATFORM.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT SOURCE.NAME FROM SOURCE ');
       SQL.Add(' RIGHT JOIN CRUISE ON ');
       SQL.Add(' CRUISE.SOURCE_ID=SOURCE.ID ');
       SQL.Add(' ORDER BY SOURCE.NAME ');
     Open;
    end;
   end;


   if (cbCountry.Text<>'') and (cbPlatform.Text='') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT SOURCE.NAME FROM ');
       SQL.Add(' COUNTRY, PLATFORM, CRUISE, SOURCE WHERE ');
       SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID AND ');
       SQL.Add(' COUNTRY.ID=PLATFORM.COUNTRY_ID AND ');
       SQL.Add(' CRUISE.SOURCE_ID=SOURCE.ID AND ');
       SQL.Add(' COUNTRY.NAME='+QuotedStr(cbCOuntry.Text));
       SQL.Add(' ORDER BY SOURCE.NAME ');
     Open;
    end;
   end;

   if (cbCountry.Text='') and (cbPlatform.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT SOURCE.NAME FROM ');
       SQL.Add(' PLATFORM, CRUISE, SOURCE WHERE ');
       SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID AND ');
       SQL.Add(' CRUISE.SOURCE_ID=SOURCE.ID AND ');
       SQL.Add(' PLATFORM.NAME='+QuotedStr(cbCOuntry.Text));
       SQL.Add(' ORDER BY SOURCE.NAME ');
     Open;
    end;
   end;

   if (cbCountry.Text<>'') and (cbPlatform.Text<>'') then begin
    With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT SOURCE.NAME FROM ');
       SQL.Add(' COUNTRY, PLATFORM, CRUISE, SOURCE WHERE ');
       SQL.Add(' CRUISE.PLATFORM_ID=PLATFORM.ID AND ');
       SQL.Add(' COUNTRY.ID=PLATFORM.COUNTRY_ID AND ');
       SQL.Add(' CRUISE.SOURCE_ID=SOURCE.ID AND ');
       SQL.Add(' COUNTRY.NAME='+QuotedStr(cbCountry.Text)+' AND ');
       SQL.Add(' PLATFORM.NAME='+QuotedStr(cbPlatform.Text));
       SQL.Add(' ORDER BY SOURCE.NAME ');
     Open;
    end;
   end;


      while not Qt.Eof do begin
        cbSource.Items.Add(Qt.Fields[0].AsString);
       Qt.Next;
      end;

    Qt.Close;
    TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;
end;

procedure Tfrmosmain.cbInstituteDropDown(Sender: TObject);
Var
  pp:integer;
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
begin
  try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;

   //DBCruiseInstitute.Items.Clear;
   cbInstitute.Clear;

     With Qt do begin
       Close;
         SQL.Clear;
         SQL.Add(' SELECT DISTINCT NAME FROM INSTITUTE ');
         SQL.Add(' RIGHT JOIN CRUISE ON ');
         SQL.Add(' CRUISE.INSTITUTE_ID=INSTITUTE.ID ');
         SQL.Add(' ORDER BY NAME ');
       Open;
      end;

      while not Qt.Eof do begin
        cbInstitute.Items.Add(Qt.Fields[0].AsString);
       Qt.Next;
      end;

  //  DBCruiseInstitute.Items:=cbInstitute.Items;

    Qt.Close;
    TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;
end;

procedure Tfrmosmain.cbProjectDropDown(Sender: TObject);
Var
  pp:integer;
  TRt:TSQLTransaction;
  Qt:TSQLQuery;
begin

 try
   TRt:=TSQLTransaction.Create(self);
   TRt.DataBase:=frmdm.IBDB;

   Qt:=TSQLQuery.Create(self);
   Qt.Database:=frmdm.IBDB;
   Qt.Transaction:=TRt;

   //DBCruiseProject.Items.Clear;
   cbProject.Clear;

   With Qt do begin
     Close;
       SQL.Clear;
       SQL.Add(' SELECT DISTINCT NAME FROM PROJECT ');
       SQL.Add(' RIGHT JOIN CRUISE ON ');
       SQL.Add(' CRUISE.PROJECT_ID=PROJECT.ID ');
       SQL.Add(' ORDER BY NAME ');
     Open;
    end;

      while not Qt.Eof do begin
        cbProject.Items.Add(Qt.Fields[0].AsString);
       Qt.Next;
      end;

  // DBCruiseProject.Items:=cbProject.Items;

    Qt.Close;
    TRt.Commit;
  finally
   Qt.Free;
   TrT.Free;
  end;
end;

procedure Tfrmosmain.CDSNavigation;
Var
ID:integer;
begin
ID:=frmdm.Q.FieldByName('ID').AsInteger;
if NavigationOrder=false then exit;

 If NavigationOrder=true then begin
  NavigationOrder:=false; //blocking everthing until previous operations have been completed

  if frmmap_open=true then frmmap.ChangeID(ID); //Map

  NavigationOrder:=true; //Завершили, открываем доступ к навигации
 end;
end;


procedure Tfrmosmain.btnMapClick(Sender: TObject);
begin
 if frmmap_open=true then frmmap.SetFocus else
    begin
       frmmap := Tfrmmap.Create(Self);
       frmmap.Show;
    end;
  frmmap.btnShowAllStationsClick(self);
  frmmap_open:=true;
end;

procedure Tfrmosmain.btnExportClick(Sender: TObject);
begin
  frmexport := Tfrmexport.Create(Self);
   try
    if not frmexport.ShowModal = mrOk then exit;
   finally
     frmexport.Free;
     frmexport := nil;
   end;
end;


(* Saving STATION search settings *)
procedure Tfrmosmain.SaveSettingsStationSearch;
Var
  Ini:TIniFile;
begin
  Ini := TIniFile.Create(IniFileName);
  try
    Ini.WriteInteger ( 'osmain', 'station_region_pcRegion', pcRegion.ActivePageIndex);
    Ini.WriteFloat   ( 'osmain', 'station_latmin',   seLatMin.Value);
    Ini.WriteFloat   ( 'osmain', 'station_latmax',   seLatMax.Value);
    Ini.WriteFloat   ( 'osmain', 'station_lonmin',   seLonMin.Value);
    Ini.WriteFloat   ( 'osmain', 'station_lonmax',   seLonMax.Value);
    Ini.WriteString  ( 'osmain', 'station_platform', cbPlatform.Text);
    Ini.WriteString  ( 'osmain', 'station_country',  cbCountry.Text);
    Ini.WriteString  ( 'osmain', 'station_source',   cbSource.Text);
    Ini.WriteString  ( 'osmain', 'station_cruise',   cbCruise.Text);
    Ini.WriteString  ( 'osmain', 'station_institute',cbInstitute.Text);
    Ini.WriteString  ( 'osmain', 'station_project',  cbProject.Text);

    Ini.WriteBool    ( 'osmain', 'station_period',   chkPeriod.Checked);
    Ini.WriteDateTime( 'osmain', 'station_datemin',  dtpDateMin.DateTime);
    Ini.WriteDateTime( 'osmain', 'station_datemax',  dtpDateMax.DateTime);
  finally
    Ini.Free;
  end;
end;

procedure Tfrmosmain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
Var
  Ini:TIniFile;
  k: integer;
begin
  Ini := TIniFile.Create(IniFileName);
   try
    Ini.WriteInteger( 'osmain', 'top',    Top);
    Ini.WriteInteger( 'osmain', 'left',   Left);
    Ini.WriteInteger( 'osmain', 'width',  Width);
    Ini.WriteInteger( 'osmain', 'weight', Height);
   finally
     Ini.Free;
   end;

   cbPlatform.Clear;
   cbCountry.Clear;
   cbSource.Clear;
   cbInstitute.Clear;
   cbProject.Clear;
end;


procedure Tfrmosmain.PopulateTblList;
Var
  TempListAll, TempListPar: TListBox;
  k, i: integer;
  tbl: string;
  fl:boolean;
begin

    try
    (* temporary list for all tables from Db *)
     TempListAll:=TListBox.Create(self);

    (* only parameters *)
     TempListPar:=TListBox.Create(self);

    (* list of all tables *)
     frmdm.IBDB.GetTableNames(TempListAll.Items,False);
     TempListAll.Sorted:=true;

     TempListPar.Clear;
     with TempListPar.Items do begin
       Add('P_TEMPERATURE');
       Add('P_SALINITY');
       Add('P_OXYGEN');
     end;

     for k:=0 to TempListAll.Items.Count-1 do begin
      if (copy(TempListAll.Items.Strings[k], 1, 2)='P_') then begin
       tbl:=TempListAll.Items.Strings[k];
        fl:=false;
        for i:=0 to TempListPar.Count-1 do begin
         if TempListPar.items.Strings[i]=tbl then fl:=true;
        end;
       if fl=false then TempListPar.Items.Add(tbl);
      end;
     end;

     for k:=0 to TempListPar.Count-1 do
      ListBox1.Items.Add(TempListPar.Items.Strings[k]);

    finally
      TempListAll.Free;
      TempListPar.Free;
    end;
end;


procedure Tfrmosmain.FormDestroy(Sender: TObject);
begin
  if frmdm.DBLoader.Enabled=true then frmdm.DBLoader.Enabled:=false;

  FreeLibrary(libgswteos);
 // FreeLibrary(netcdf);

  if frmmap_open then frmmap.Close;
end;

end.


