unit dm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, Controls, IBConnection, sqldb, sqldblib,
  BufDataset, db;

type

  { Tfrmdm }

  Tfrmdm = class(TDataModule)
    DS: TDataSource;
    IBDB: TIBConnection;
    Q: TSQLQuery;
    q1: TSQLQuery;
    q2: TSQLQuery;
    q3: TSQLQuery;
    DBLoader: TSQLDBLibraryLoader;
    QCruise: TSQLQuery;
    TR: TSQLTransaction;

    procedure DataModuleDestroy(Sender: TObject);

  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmdm: Tfrmdm;


implementation

{$R *.lfm}

{ Tfrmdm }

uses osmain;



procedure Tfrmdm.DataModuleDestroy(Sender: TObject);
begin
 TR.Commit;
 IBDB.Close(true);
end;

end.

