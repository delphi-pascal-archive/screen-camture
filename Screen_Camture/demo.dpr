program demo;

uses
  Forms,
  unit1 in 'unit1.pas' {Form1},
  VFW in 'vfw.pas',
  optdlg in 'optdlg.pas' {OptionDlg},
  scrcam in 'scrcam.pas',
  flashwnd in 'flashwnd.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'ScreenCamture v0.2';
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TOptionDlg, OptionDlg);
  Application.Run;
end.
