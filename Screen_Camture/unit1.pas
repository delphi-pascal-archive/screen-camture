unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, scrcam, flashwnd, Buttons, ExtCtrls, Mask, UnPas2;

type
  TForm1 = class(TForm)
    PanelHaut: TPanel;
    FileName: TEdit;
    bt_record: TSpeedButton;
    bt_options: TSpeedButton;
    lblInfos: TLabel;
    SaveDialog: TSaveDialog;
    Button1: TButton;
    Panel1: TPanel;
    Image1: TImage;
    Image2: TImage;
    Image3: TImage;
    Image4: TImage;
    PanelPub: TPanel;
    lblpub3: TLabel;
    lblpub2: TLabel;
    lblpub1: TLabel;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    chkMouse: TCheckBox;
    Bevel1: TBevel;
    UnPas2: TUnPas2;
    procedure FormCreate(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure bt_recordClick(Sender: TObject);
    procedure bt_optionsClick(Sender: TObject);
    procedure FilenameChange(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure FormCanResize(Sender: TObject; var NewWidth,
      NewHeight: Integer; var Resize: Boolean);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure Fleches(Sender: TObject);
    procedure chkMouseClick(Sender: TObject);
  private
    procedure UpdateForm(Sender : TObject);
  public
  end;

var
  Form1: TForm1;
  scrcam: TScreenCam;

implementation

uses optdlg;

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  scrCam:=TScreenCam.create(self);
  scrCam.OnUpdate:= UpdateForm;
  scrcam.flashingRect:= false;
end;

procedure TForm1.UpdateForm(Sender: TObject);
begin
  lblinfos.Caption:=format('ms/Frame: %f'#10#13'FrameNr: %d'#10#13'Skipped Frames: %d',[scrcam.ActualmspF, scrcam.AcutalFrameNo, scrcam.SkippedFrames]);
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  scrCam.getCompressorsInfo;
  OptionDlg.execute;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  scrCam.free;
end;

procedure TForm1.bt_recordClick(Sender: TObject);
begin
 if bt_record.Down then
  begin
   bt_record.caption := 'Stop';
   scrcam.autoPan         := true;
   if fileexists(FileName.Text) then
     deletefile(filename.Text);
   scrcam.startRecording(form1, FileName.Text);
   AlphaBlend:= True;
   BorderStyle:= bsDialog;
   EnableMenuItem(GetSystemMenu(Handle, FALSE), SC_CLOSE, MF_GRAYED);
  end
 else
  begin
   bt_record.caption := 'Rec.';
   AlphaBlend:= False;
   PanelHaut.Visible:= False;
   TransparentColor:= False;
   BorderStyle:= bsNone;
   PanelPub.Visible:= True;
   application.ProcessMessages;
   sleep(250);
   Application.RestoreTopMosts;
   scrCam.stopRecording;
   PanelPub.Visible:= False;
   BorderStyle:= bsSizeable;
   PanelHaut.Visible:= True;
   TransparentColor:= True;
   if fileexists(FileName.Text) then
        lblinfos.Caption := 'Enregistrement terminé !'
   else lblinfos.Caption := 'Erreur lors de l''enregistrement';
  EnableMenuItem(GetSystemMenu(Handle, FALSE), SC_CLOSE, MF_ENABLED);
  end;
  chkMouse.Enabled:= not bt_record.Down;
end;

procedure TForm1.bt_optionsClick(Sender: TObject);
begin
  scrCam.getCompressorsInfo;
  OptionDlg.execute;
end;

procedure TForm1.FilenameChange(Sender: TObject);
begin
  bt_record.Enabled := length(filename.Text)>=6;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
  if SaveDialog.Execute then
    FileName.Text:= SaveDialog.FileName;
end;

procedure TForm1.FormCanResize(Sender: TObject; var NewWidth,
  NewHeight: Integer; var Resize: Boolean);
begin
  resize:= not bt_record.Down;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose:= not bt_record.Down;
end;

procedure TForm1.Fleches(Sender: TObject);
begin
  case TImage(sender).Tag of
   1: PanelHaut.Top:= 0;
   2: PanelHaut.Left:= 0;
   3: PanelHaut.Left:= ClientWidth-PanelHaut.Width;
   4: PanelHaut.Top:= ClientHeight-PanelHaut.Height;
  end;
end;

procedure TForm1.chkMouseClick(Sender: TObject);
begin
  scrcam.recordCursor:= chkMouse.Checked;
end;

end.
