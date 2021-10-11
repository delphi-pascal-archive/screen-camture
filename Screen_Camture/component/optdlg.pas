unit optdlg;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, unit1, Math;

type
  TOptionDlg = class(TForm)
    Compressor: TGroupBox;
    ComboBoxCompressor: TComboBox;
    ButtonAbout: TButton;
    TrackBarQuality: TTrackBar;
    Label1: TLabel;
    LabelQuality: TLabel;
    GroupBox1: TGroupBox;
    ButtonConfig: TButton;
    Button2: TButton;
    Button3: TButton;
    GroupBox2: TGroupBox;
    Label5: TLabel;
    TrackBarPlayback: TTrackBar;
    Label7: TLabel;
    EditKeyFrames: TEdit;
    Label3: TLabel;
    Label2: TLabel;
    TrackBarRecord: TTrackBar;
    Label4: TLabel;
    Label6: TLabel;
    labelmspFrecord: TLabel;
    labelFPSPlayback: TLabel;
    procedure ButtonAboutClick(Sender: TObject);
    procedure ButtonConfigClick(Sender: TObject);
    procedure ComboBoxCompressorSelect(Sender: TObject);
    procedure TrackBarPlaybackChange(Sender: TObject);
    procedure TrackBarQualityChange(Sender: TObject);
  private
    { Private declarations }
    procedure RefreshCompressorButtons;
    procedure updateAdjustSliderVal;
  public
    { Public declarations }
    auto: boolean;
    function execute: boolean;
  end;

var
  OptionDlg: TOptionDlg;

implementation

{$R *.dfm}

function TOptionDlg.execute: boolean;
var
  i: integer;
begin
  comboBoxCompressor.clear;
  for i:=0 to scrcam.compressorCount-1 do
  begin
    comboBoxCompressor.Items.Add(scrcam.CompressorInfo[i].szDescription);
  end;
  comboBoxCompressor.ItemIndex:=0;

  trackbarrecord.position:=round(log10(scrCam.mspFRecord)*(trackbarrecord.max-1)/log10(60000)+1);
  trackbarplayback.position:=round((scrCam.FPSPlayback-1)*(trackbarplayback.max-1)/49);

  editkeyframes.text:=format('%d', [10]);
  editKeyFrames.text:=format('%d', [scrCam.KeyFramesEvery]);
  trackBarQuality.Position:=round(scrCam.compressionQuality*trackbarquality.max/10000);

  RefreshCompressorButtons;

  if showModal = mrOK then
  begin
    scrcam.selectedCompressor:=comboBoxCompressor.itemIndex;
    scrcam.compressionQuality:=round(trackbarQuality.position*10000/trackbarQuality.max); // maximum of compressionQuality is 10000
    scrcam.KeyFramesEvery:=strToInt(editKeyFrames.text);
    scrcam.msPFRecord:=round(power(10,(trackbarrecord.Position-1)*log10(60000)/(trackbarrecord.max-1) ));
    scrcam.FPSPlayback:=round((trackbarplayback.Position-1)*49/(trackbarplayback.Max-1)+1);
  end;
end;

procedure TOptionDlg.ButtonAboutClick(Sender: TObject);
var
  idx: integer;
begin
  idx:=ComboBoxCompressor.itemindex;
  scrCam.compressorAbout(idx, windowhandle);
end;

procedure TOptionDlg.ButtonConfigClick(Sender: TObject);
var
  idx: integer;
begin
  idx:=ComboBoxCompressor.itemindex;
  scrCam.compressorConfigure(idx, windowhandle);
end;

procedure TOptionDlg.ComboBoxCompressorSelect(Sender: TObject);
begin
	RefreshCompressorButtons;
end;

procedure TOptionDlg.RefreshCompressorButtons;
var
  idx: integer;
  about, config: boolean;
begin
  idx:=ComboBoxCompressor.itemindex;
  scrCam.compressorHasFeatures(idx, about, config);
  ButtonAbout.enabled:=about;
  ButtonConfig.enabled:=config;
end;


procedure TOptionDlg.updateAdjustSliderVal;
var
  lmspFRecord, lFPSPlayback : integer;
begin
  lmspFRecord:=round(power(10,(trackbarrecord.Position-1)*log10(60000)/(trackbarrecord.max-1) ));
  lFPSPlayback:=round((trackbarplayback.Position-1)*49/(trackbarplayback.Max-1)+1);
  labelmspfRecord.caption:=format('%d ms', [lmspFRecord]);
  labelFPSPlayback.caption:=format('%d fps', [lFPSPlayback]);
  labelQuality.caption:=IntToStr(trackBarQuality.Position);
end;


procedure TOptionDlg.TrackBarPlaybackChange(Sender: TObject);
begin
  updateAdjustSliderVal;
end;

procedure TOptionDlg.TrackBarQualityChange(Sender: TObject);
begin
  updateAdjustSliderVal;
end;

end.
