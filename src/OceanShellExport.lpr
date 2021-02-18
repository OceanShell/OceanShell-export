program OceanShellExport;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
    {$IFDEF UseCThreads}
     cthreads,
    {$ENDIF}
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, osmain, dm, icons, GibbsSeaWater, osexport_hdb, osexport_netcdf;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(Tfrmdm, frmdm);
  Application.CreateForm(Tfrmosmain, frmosmain);
  Application.CreateForm(Tfrmicons, frmicons);
  Application.Run;
end.

