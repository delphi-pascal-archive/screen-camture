// Screen Cam Component (recording screen activity to video)
// for Delphi 7
// Developed 2003 by Christian & Alexander Grau (alexander_grau@gmx.de)
// see README.TXT for license details

unit scrcam;

interface

uses  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, vfw, mmsystem, flashwnd;

type
  TScreenCamEvent = procedure (Sender: TObject) of object;

  TRecordAVIThread = class;

  TICINFOS = array[0..31] of TICINFO;

  TScreenCam = class(TObject)
  private
    FOwner: TComponent;
    bits: integer;
    nColors: integer;
    compfccHandler: DWORD;
    strCodec: string;
    recordstate: boolean;
    maxxScreen, maxyScreen: integer;
    initialtime: DWORD;
    FActualmspF : real;
    FSkippedFrames : integer;
    FComputedFrameNo, FActualFrameNo : integer;
    actualwidth, actualheight: integer;
    FOnUpdate, FOnStart, FOnStop, FOnError: TScreenCamEvent;
    FrecordAVIThread: TRecordAVIThread;
    FPlaybackFPS : integer; // MSPF=MillisecondsPerFrame
    FmspFRecord  : integer;
    FKeyFramesEvery: integer;
    FselectedCompressor: integer;
    FCompressionQuality: integer;
    FCompressorCount: integer;
    FcompressorInfo: TICINFOS;
    Frecordcursor: boolean;
    FFrame: TFlashingWnd;
    FFlashingRect: boolean;
    FCursor: hcursor;
    Fautopan: boolean;
    function captureScreenFrame(left, top, width, height: integer): PBITMAPINFOHEADER;
    procedure ThreadDone(Sender: TObject);
    function recordVideo(aForm: tcustomForm; szFilename: string): integer;
    procedure DrawFlashingRect(bDraw: boolean);
  public
    constructor create(owner: TComponent); virtual;
    destructor destroy; override;
    function startRecording(Form: tcustomForm; szFilename: string): boolean;
    procedure stopRecording;
    procedure getCompressorsInfo;
    procedure compressorAbout(compressor: byte; wnd: hwnd);
    procedure compressorHasFeatures(compressor: byte; var hasAbout: boolean; var hasConfig: boolean);
    procedure compressorConfigure(compressor: byte; wnd: hwnd);
    procedure AutoSetRate(val: integer; var framerate: integer; var delayms: integer);
    // report values (read-only)
    property ComputedFrameNo : integer read FComputedFrameNo;
    property AcutalFrameNo : integer read FActualFrameNo;
    property ActualmspF: real read FActualmspF;      // actual FPS rate = should be Playback-fps rate on fast machines!
    property SkippedFrames : integer read FSkippedFrames;
    property colors: integer read nColors;
    property codec: string read strCodec;
    property width: integer read actualWidth;
    property height: integer read actualHeight;
    property compressorCount: integer read FCompressorCount;
    property compressorInfo: TICINFOS read FCompressorInfo;
  protected
  published
    // options
    property FPSPlayback: integer read FPlaybackFPS write FPlaybackFPS;  // = FPS Playback rate
    property msPFRecord: integer read FmsPFRecord write FmsPFRecord;  // = FPS Record rate
    property KeyFramesEvery: integer read FKeyFramesEvery write FKeyFramesEvery;     // key frame rate
    property compressionQuality: integer read FCompressionQuality write FCompressionQuality; // 1 - 10000
    property SelectedCompressor: integer read FSelectedCompressor write FSelectedCompressor;
    property recordCursor: boolean read FRecordCursor write FRecordCursor;
    property flashingRect: boolean read FFlashingRect write FFlashingRect;
    property autoPan: boolean read FAutopan write FAutopan;
    // events
    property OnError: TScreenCamEvent read FOnError write FOnError;
    property OnUpdate: TScreenCamEvent read FOnUpdate write FOnUpdate;
    property OnStart: TScreenCamEvent read FOnStart write FOnStart;
    property OnStop: TScreenCamEvent read FOnStop write FOnStop;
  end;


  TRecordAVIThread = class(TThread)
  private
    FScrCam: TScreenCam;
    FFps: integer;
    FszFilename: string;
    FForm: TCustomForm;
  protected
    procedure Execute; override;
  public
    FlashCol: COLORREF;
    FlashLeft,
    FlashTop,
    FlashWidth,
    FlashHeight: integer;
    constructor Create(scrcam: TScreenCam; Form: tcustomForm; fps: integer; szFilename: string);
    procedure FlashPaintBorder;
    procedure FlashsetupRegion;
  end;



implementation

const
  hWndGlobal = 0;


procedure TScreenCam.DrawFlashingRect(bDraw: boolean);
begin
  (*if (bDraw) then
    FFrame.PaintBorder(RGB(255,255,180))
  else
  	FFrame.PaintBorder(RGB(0,255,80));
  *)
  if (bDraw) then
    FrecordAVIThread.flashcol:=RGB(255,255,180)
  else
  	FrecordAVIThread.flashcol:=RGB(0,255,80);
  FrecordAVIThread.synchronize(FrecordAVIThread.FlashPaintBorder);
end;


constructor TScreenCam.create(owner: TComponent);
var
  hScreenDC: HDC;
begin
  FOwner:=owner;
  recordstate:=FALSE;
  FcompressorCount:=0;
  FSelectedCompressor:=-1;

	hScreenDC := GetDC(0);
	bits := GetDeviceCaps(hScreenDC, BITSPIXEL );
	nColors := bits;
	maxxScreen := GetDeviceCaps(hScreenDC,HORZRES);
	maxyScreen := GetDeviceCaps(hScreenDC,VERTRES);
	ReleaseDC(0, hScreenDC);

	compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');

  FmsPFRecord:=100;
  FPlaybackFPS:=10;
  FKeyFramesEvery:=5; // every 5 frames keyframe
  FcompressionQuality:=6550;
  FSelectedCompressor:=-1;
  FRecordCursor:=TRUE;
  FFrame:=TFlashingWnd.create(owner);
  FFlashingRect:=TRUE;
  FCursor:=LoadCursor(0, IDC_ARROW);
  FAutopan:=FALSE;
  FRecordAVIThread:=NIL;
end;

destructor TScreenCam.destroy;
begin
  FFrame.free;
end;


procedure TScreenCam.compressorAbout(compressor: byte; wnd: hwnd);
var
  ic: hic;
begin
  if compressor >= FCompressorCount then exit;
	ic := ICOpen(FCompressorInfo[compressor].fccType, FCompressorInfo[compressor].fccHandler, ICMODE_QUERY);
	if (ic <> 0) then
  begin
  	ICAbout(ic, wnd);
    ICClose(ic);
  end;
end;

procedure TScreenCam.compressorConfigure(compressor: byte; wnd: hwnd);
var
  ic: hic;
begin
  if compressor >= FCompressorCount then exit;
	ic := ICOpen(FCompressorInfo[compressor].fccType, FCompressorInfo[compressor].fccHandler, ICMODE_QUERY);
	if (ic <> 0) then
  begin
  	ICConfigure(ic, wnd);
    ICClose(ic);
  end;
end;


procedure TScreenCam.compressorHasFeatures(compressor: byte; var hasAbout: boolean; var hasConfig: boolean);
var
  ic: hic;
begin
  hasAbout:=FALSE;
  hasConfig:=FALSE;
  if compressor >= FCompressorCount then exit;
	ic := ICOpen(FCompressorInfo[compressor].fccType, FCompressorInfo[compressor].fccHandler, ICMODE_QUERY);
	if (ic <> 0)  then
  begin
  	hasAbout:=ICQueryAbout(ic);
  	hasConfig:=ICQueryConfigure(ic);    
    ICClose(ic);
  end;
end;


function Bitmap2Ddb( hbitmap: HBITMAP; bits: longword ): THANDLE;
var
	hdib: THANDLE;
  ahdc: HDC;
	bitmap: windows.TBITMAP;
	wLineLen: longword;
	dwSize: DWORD;
	wColSize: DWORD;
	lpbi: PBITMAPINFOHEADER;
	lpBits: PBYTE;
begin
	GetObject(hbitmap,sizeof(BITMAP),@bitmap) ;

	// DWORD align the width of the DIB
	// Figure out the size of the colour table
	// Calculate the size of the DIB
	//
	wLineLen := (bitmap.bmWidth*bits+31)div 32 * 4;
  if (bits <= 8) then wColSize:=sizeof(RGBQUAD)* (1 SHL bits)
    else wColSize:=0;
	dwSize := sizeof(BITMAPINFOHEADER) + wColSize +
		wLineLen*bitmap.bmHeight;

	//
	// Allocate room for a DIB and set the LPBI fields
	//
	hdib := GlobalAlloc(GHND,dwSize); //allocate bitmap handle
	if (hdib=0) then
  begin
		result:=hdib;
    exit;
  end;

	lpbi := GlobalLock(hdib) ;  // lock bitmap handle and get back pointer

	lpbi^.biSize := sizeof(BITMAPINFOHEADER) ;
	lpbi^.biWidth := bitmap.bmWidth ;
	lpbi^.biHeight := bitmap.bmHeight ;
	lpbi^.biPlanes := 1 ;
	lpbi^.biBitCount := bits ;
	lpbi^.biCompression := BI_RGB ;
	lpbi^.biSizeImage := dwSize - sizeof(BITMAPINFOHEADER) - wColSize ;
	lpbi^.biXPelsPerMeter := 0 ;
	lpbi^.biYPelsPerMeter := 0 ;
  if bits <= 8 then lpbi^.biClrUsed := 1 SHL bits
    else lpbi^.biClrUsed:=0;
	lpbi^.biClrImportant := 0 ;

	//
	// Get the bits from the bitmap and stuff them after the LPBI
	//
	lpBits := pointer(longword(lpbi)+lpbi^.biSize+wColSize) ;

	ahdc := CreateCompatibleDC(0) ;

  // retrieve the bits of hbitmap and copy them into the buffer lpBits using the specified format in lpbi
  if GetDIBits(ahdc,hbitmap,0,bitmap.bmHeight,lpBits,PBITMAPINFO(lpbi)^, DIB_RGB_COLORS) = 0 then
  begin
    messagebox(0, 'Error retrieving bitmap bits', 'Error', mb_ok);
  end;

  if bits <= 8 then	lpbi^.biClrUsed := (1 SHL bits)
    else lpbi^.biClrUsed:=0;

	DeleteDC(ahdc) ;
	GlobalUnlock(hdib);

	result:=hdib ;
end;


function TScreenCam.captureScreenFrame(left, top, width, height: integer): PBITMAPINFOHEADER;
var
	hScreenDC: HDC;
  hMemDC: HDC;
  hbm: HBITMAP;
  oldbm: HBITMAP;
  pBM_HEADER: PBITMAPINFOHEADER;
  xpoint, highlightPoint: TPOINT;
  hcur: HCURSOR;
  aniconinfo: ICONINFO;
	ret: BOOL;
begin
  hScreenDC:=GetDC(0);

	//if flashing rect
	if (FflashingRect) AND (FRecordAVIThread <> NIL) then
  begin
    if Fautopan then
    begin
      //FFrame.SetUpRegion(left,top,width,height);
      FRecordAVIThread.flashLeft:=left;
      FRecordAVIThread.flashTop:=top;
      FRecordAVIThread.flashWidth:=width;
      FRecordAVIThread.flashHeight:=height;
      FrecordAVIThread.synchronize(FrecordAVIThread.FlashSetupRegion);
    end;
  	DrawFlashingRect( TRUE );
  end;

  hMemDC:=CreateCompatibleDC(hScreenDC);

  hbm := CreateCompatibleBitmap(hScreenDC, width, height);
 	oldbm := SelectObject(hMemDC, hbm);
	BitBlt(hMemDC, 0, 0, width, height, hScreenDC, left, top, SRCCOPY); // bit block transfer from  hScreenDC to hMemdc

	//Get Cursor Pos
	GetCursorPos( xPoint );
  hcur:= windows.getCursor;
	dec(xPoint.x, left);
	dec(xPoint.y, top);

	//Draw the Cursor
	if (FrecordCursor) then
  begin
		ret	:= GetIconInfo( hcur,  aniconinfo );
		if (ret) then
    begin
			dec(xPoint.x, aniconinfo.xHotspot);
			dec(xPoint.y, aniconinfo.yHotspot);

			//need to delete the hbmMask and hbmColor bitmaps
			//otherwise the program will crash after a while after running out of resource
			if (aniconinfo.hbmMask <> 0) then DeleteObject(aniconinfo.hbmMask);
			if (aniconinfo.hbmColor <> 0) then DeleteObject(aniconinfo.hbmColor);
    end;
		DrawIcon( hMemDC,  xPoint.x,  xPoint.y, fcursor); // hcur
	end;

	SelectObject(hMemDC,oldbm);
	pBM_HEADER := GlobalLock(Bitmap2Ddb(hbm, bits));	// lock bitmap handle and get pointer
	//LPBITMAPINFOHEADER pBM_HEADER = (LPBITMAPINFOHEADER)GlobalLock(Bitmap2Dib(hbm, 24));
	if (pBM_HEADER = NIL) then
  begin
		MessageBox(0,'Error capturing a frame!','Error',MB_OK OR MB_ICONEXCLAMATION);
		result:=NIL; exit;
	end;

	DeleteObject(hbm);
	DeleteDC(hMemDC);

	//if flashing rect
	if (FflashingRect) AND (FRecordAVIThread <> NIL) then
  	DrawFlashingRect( FALSE );

	ReleaseDC(0, hScreenDC) ;

  result:=pBM_HEADER;
end;

procedure FreeFrame(var alpbi: PBITMAPINFOHEADER);
begin
	if (alpbi=NIL) then exit;

	GlobalFreePtr(alpbi);
	//GlobalFree(alpbi);
	alpbi := 0;
end;


procedure TScreenCam.getCompressorsInfo;
var
  ic: hic;
 	first_alpbi: PBITMAPINFOHEADER;
  i: integer;
begin
  first_alpbi:=captureScreenFrame(0,0,320,200);
  FcompressorCount:=0;
  for i:=0 to 31 do
  begin
   	ICInfo(ICTYPE_VIDEO, i, @FCompressorInfo[FCompressorCount]);
 		ic := ICOpen(FCompressorInfo[FCompressorCount].fccType, FCompressorInfo[FCompressorCount].fccHandler, ICMODE_QUERY);
		if (ic <> 0) then
    begin
			if (ICERR_OK=ICCompressQuery(ic, first_alpbi, NIL)) then
      begin
				ICGetInfo(ic, @FCompressorInfo[FCompressorCount], sizeof(TICINFO));
    		inc(FCompressorCount);
      end;
			ICClose(ic);
    end;
  end;
	FreeFrame(first_alpbi);
end;


function TScreenCam.recordVideo(aForm: tcustomForm; szFilename: string): integer;
var
	alpbi: PBitmapInfoHeader;
	strhdr: TAVIStreamInfo;
	pfile: PAVIFILE;
	ps: PAVISTREAM;
  psCompressed: PAVISTREAM;
  opts: TAVICOMPRESSOPTIONS;
	aopts: array[0..0] of PAVICOMPRESSOPTIONS;
	hr: HRESULT;
  wVer: WORD;
	szTitle: string;
  ic: HIC;
  newleft,newtop,newwidth,newheight: integer;
  align: integer;
  hm, wm: integer;
  top, left, width, height: integer;
 	timeexpended, savingtime, oldframetime, oldupdatetime : longword;
  oldcomputedframeno, sleepdivider: integer;
	divx, oldsec: longword;
  remaintime, no_iteration, j: integer;
label
  error;
begin
  top:=aForm.Top;
  left:=aForm.left;
  width:=aForm.width;
  height:=aForm.height;

  actualwidth:=width;
	actualheight:=height;

	wVer := HIWORD(VideoForWindowsVersion());
	if (wVer < $010a) then
  begin
  	MessageBox(0, 'Failure: Video for Windows version too old!', 'Error' , MB_OK OR MB_ICONSTOP);
    if assigned(FOnError) then FOnError(self);
		result:=0;
    exit;
	end;

	// CAPTURE FIRST FRAME -------------------------------------------
	alpbi:=captureScreenFrame(left,top,width, height);
  // ---------------------------------------------------------------

	// TEST VALIDITY OF COMPRESSOR  
  if (FselectedCompressor <> -1) then
  begin
		ic := ICOpen(FCompressorInfo[FSelectedCompressor].fccType, FCompressorInfo[FSelectedCompressor].fccHandler, ICMODE_QUERY);
		if (ic <> 0) then
    begin
      align:=1;
			while (ICERR_OK <> ICCompressQuery(ic, alpbi, NIL)) do
      begin
				//Try adjusting width/height a little bit
				align := align * 2 ;		
				if (align>8) then break;

				newleft:=left;
				newtop:=top;
				wm := (width MOD align);
				if (wm > 0) then
        begin
					newwidth := width + (align - wm);
					if (newwidth>maxxScreen) then
						newwidth := width - wm;
				end;

				hm := (height MOD align);
				if (hm > 0) then
        begin
					newheight := height + (align - hm);
					if (newheight>maxyScreen) then
						newwidth := height - hm;
				end;

				if (alpbi <> NIL) then FreeFrame(alpbi);
				alpbi:=captureScreenFrame(newleft,newtop,newwidth, newheight);
      end;

			//if succeed with new width/height, use the new width and height
			//else if still fails ==> default to MS Video 1 (MSVC)							
			if (align = 1) then
      begin
				//Compressor has no problem with the current dimensions...so proceed
				//do nothing here
			end	else if  (align <= 8) then
      begin
					//Compressor can work if the dimensions is adjusted slightly
					left:=newleft;
					top:=newtop;
					width:=newwidth;
					height:=newheight;

					actualwidth:=newwidth;
					actualheight:=newheight;
			end	else
      begin
					compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');
					strCodec := 'Default Compressor';
			end;
			ICClose(ic);

		end else
    begin
			compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');
			strCodec := 'Default Compressor';
			//MessageBox(NULL,"hic default","note",MB_OK);
		end;
	end;

	//Special Cases
	{if (compfccHandler=mmioFOURCC('D', 'I', 'V', 'X')) then
	begin //Still Can't Handle DIVX
		compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');
		strCodec := 'Default Compressor';
	end;}

	if (compfccHandler=mmioFOURCC('I', 'V', '5', '0')) then
	begin //Still Can't Handle Indeo 5.04
		compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');
		strCodec := 'Default Compressor';
  end;

	// Set Up Flashing Rect
	if (FflashingRect) then
  begin
		FFrame.SetUpRegion(left,top,width,height);
		ShowWindow(FFrame.handle, SW_SHOW);
	end;

	// INIT AVI USING FIRST FRAME
	AVIFileInit;    
	// Open the movie file for writing....
	hr := AVIFileOpen(pfile, pchar(szFileName), OF_WRITE OR OF_CREATE, NIL);
	if (hr <> AVIERR_OK) then goto error;

	// Fill in the header for the video stream....
	// The video stream will run in 15ths of a second....
  fillchar(strhdr, sizeof(strhdr), 0);
	strhdr.fccType                := streamtypeVIDEO;// stream type

	//strhdr.fccHandler             = compfccHandler;
	strhdr.fccHandler             := 0;

	strhdr.dwScale                := 1;   // no time scaling
	strhdr.dwRate                 := FPlaybackFPS;  // set playback rate in fps
	strhdr.dwSuggestedBufferSize  := alpbi^.biSizeImage;
	SetRect(strhdr.rcFrame, 0, 0,		    // rectangle for stream
	    alpbi^.biWidth,
	    alpbi^.biHeight);

	// And create the stream;
	hr := AVIFileCreateStream(pfile,	ps, @strhdr); // returns ps as uncompressed stream pointer
	if (hr <> AVIERR_OK) then	goto error;

  fillchar(opts, sizeof(opts), 0);
  longword(aopts[0]):=longword(@opts);
	aopts[0]^.fccType			 := streamtypeVIDEO;
	//aopts[0]->fccHandler		 = mmioFOURCC('M', 'S', 'V', 'C');
	aopts[0]^.fccHandler		 := compfccHandler;
	aopts[0]^.dwKeyFrameEvery	   := FkeyFramesEvery;		// keyframe rate
	aopts[0]^.dwQuality		 := FCompressionQuality;    // compress quality 0-10,000
	aopts[0]^.dwBytesPerSecond	         := 0;		// bytes per second
	aopts[0]^.dwFlags			 := AVICOMPRESSF_VALID OR AVICOMPRESSF_KEYFRAMES;    // flags
	aopts[0]^.lpFormat			 := $00;                         // save format
	aopts[0]^.cbFormat			 := 0;
	aopts[0]^.dwInterleaveEvery := 0;			// for non-video streams only

	hr := AVIMakeCompressedStream(psCompressed, ps, @opts, NIL);  // compress ps stream to psCompressed 
	if (hr <> AVIERR_OK) then	goto error;

	hr := AVIStreamSetFormat(psCompressed, 0,
			       alpbi,	    // stream format      (this is the first frame!)
			       alpbi^.biSize +   // format size
			       alpbi^.biClrUsed * sizeof(RGBQUAD));
	if (hr <> AVIERR_OK) then goto error;

 	FreeFrame(alpbi);
	alpbi:=NIL;

  sleepdivider:=FmspFRecord div 10;
  if sleepdivider=0 then sleepdivider:=1;

	// WRITING FRAMES
	divx:=0;
	oldsec:=0;

  if assigned(FOnStart) then FOnStart(self);

  oldframetime:= 0;
  oldupdatetime := 0;
	oldComputedframeno := 0;
  FActualFrameNo := 0;
  fActualmspF := 0;
	initialtime := timeGetTime;
  FSkippedFrames:=0;

  // ===============  recording loop =====================================================
	while (recordstate) do  //repeatedly loop
  begin
    timeexpended := timeGetTime - initialtime; // timeexpended = verstrichene Zeit seit Video-Beginn in ms
    if Fautopan then
    begin
      alpbi:=captureScreenFrame(aform.left,aform.top,aform.width, aform.height);
    end else alpbi:=captureScreenFrame(left,top,width, height);

    FComputedFrameno := round (timeexpended / FmspFRecord); // loop duty - time syncronous

    if (FComputedFrameno-oldComputedframeno)>1 then
      inc(FskippedFrames, FComputedFrameno-oldComputedframeno-1);

		if (FComputedframeno=0) OR (FComputedframeno>oldComputedframeno) then // (video start) or (new loop=(keyframe) necessary) ?
    begin
			//if frameno repeats...the avistreamwrite will cause an error
			hr := AVIStreamWrite(psCompressed,	// stream pointer
				FComputedframeno,				// number this frame
				1,				// number to write
				PBYTE (longword(alpbi) +		// pointer to data
					alpbi^.biSize +
					alpbi^.biClrUsed * sizeof(RGBQUAD)),
					alpbi^.biSizeImage,	// size of this frame
				//AVIIF_KEYFRAME,			 // flags....
				0,    //Dependent n previous frame, not key frame
				NIL,
				NIL);
			if (hr <> AVIERR_OK) then break;

			inc(FActualFrameNo); // just a counter
  		fActualmspF := (TimeExpended-OldFrameTime);
      OldFrameTime:=TimeExpended;
      oldComputedframeno:=FComputedframeno;

			//free memory
			FreeFrame(alpbi);
			alpbi:=NIL;

		end;

    //Update record stats every half a second
    if (timeexpended>oldupdatetime+500) then
    begin
      oldUpdateTime:=TimeExpended;
      //InvalidateRect(hWndGlobal, NIL, FALSE);  // <=====  ??? was soll das ???
      if assigned(FOnUpdate) then FOnUpdate(self); // user event für aktuellen Status (z.B. Zeit) anzeigen etc.
    end;

    savingtime:=((timeGetTime - initialtime) - timeexpended); // = time for saving frame
    if savingtime >= FmspFRecord then // saving took to much time => hurry up / notice user!!!
    begin
    end
    else
    begin // ok, we have to wait.....
  		//introduce time lapse  ( for creating long time movies, e.g. every hour one shot )
      no_iteration := (FmspFRecord - savingtime) div sleepdivider;  // number of sleepdivider lapses
      remaintime := (FmspFRecord - savingtime) - no_iteration*sleepdivider;  // rest of integer DIV
      for j:=0 to no_iteration-1 do      // loop the lapses
      begin
        Sleep(sleepdivider); //Sleep for sleepdivider milliseconds many times
        if (recordstate=FALSE) then break;
      end;
      if (recordstate=TRUE) then Sleep(remaintime);
    end
	end;
  // ===============  recording loop ends =====================================================

  if assigned(FOnStop) then FOnStop(self);

error:


	// Now close the file
	if (FflashingRect) then	ShowWindow(FFrame.handle, SW_HIDE);

	AVISaveOptionsFree(1, PAVICOMPRESSOPTIONS(aopts[0]));  // sometimes crashes here...!!
	if (pfile <> NIL) then AVIFileClose(pfile);
	if (ps <> NIL ) then AVIStreamClose(ps);
	if (psCompressed <> NIL) then	AVIStreamClose(psCompressed);

	AVIFileExit();

	if (hr <> NOERROR) then
  begin
    if assigned(FOnError) then FOnError(self);
		if (compfccHandler <> mmioFOURCC('M', 'S', 'V', 'C'))	then
    begin
			if (IDYES = MessageBox(0, 'Error recording AVI file using current compressor. Use default compressor? ', 'Notice', MB_YESNO OR MB_ICONEXCLAMATION)) then
      begin
				compfccHandler := mmioFOURCC('M', 'S', 'V', 'C');
				strCodec := 'Default Compressor';
        // indicate to restart recording...
        result:=-1;
			end;
		end else
    begin
			MessageBox(0, 'Error Creating AVI file', 'Error', MB_OK OR MB_ICONEXCLAMATION);
      result:=0;
    end;

    exit;
  end;

	//Save the file on success
	result:=1;
end;

procedure TScreenCam.stopRecording;
begin
  recordState:=FALSE;
end;

function TScreenCam.startRecording(Form: tcustomForm; szFilename: string): boolean;
begin
  if recordState then exit; // exit if still recording
  FRecordAVIThread:=TRecordAVIThread.create(self, form, fPlaybackFPS, szFilename);
  //FRecordAVIThread.Priority:=tpHighest;
  FRecordAVIThread.onTerminate:=ThreadDone;
  recordState:=TRUE;
end;

// message from thread informing that it is done
procedure TScreenCam.ThreadDone(Sender: TObject);
begin
  recordState:=FALSE;
  FRecordAVIThread:=NIL;
end;



procedure TScreenCam.AutoSetRate(val: integer; var framerate: integer; var delayms: integer);
begin
	if (val<=17) then //fps more than 1 per second
  begin
		framerate:=200-((val-1)*10); //framerate 200 to 40;
		//1 corr to 200, 17 corr to 40
		delayms := 1000 div framerate;
	end
	else if (val<=56) then //fps more than 1 per second
  begin
		framerate:=(57-val); //framerate 39 to 1;
		//18 corr to 39,  56 corr to 1
		delayms := 1000 div framerate;
	end
	else if (val<=86) then //assume timelapse
  begin
		framerate := 20;
		delayms := (val-56)*1000;
		//57 corr to 1000, 86 corr to 30000 (20 seconds)
	end
	else if (val<=99) then //assume timelapse
  begin
		framerate := 20;
		delayms := (val-86)*2000+30000;
		//87 corr to 30000, 99 corr to 56000 (56 seconds)
	end
	else begin //val=100 , timelapse
		framerate := 20;
		delayms := 60000;

		//100 corr to 60000
  end;
end;




// --------------------------------------------------------------------------
//    TRecordAVI Thread
// --------------------------------------------------------------------------

constructor TRecordAVIThread.Create(scrcam: TScreenCam; Form: tcustomForm; fps: integer; szFilename: string);
begin
  FScrCam:=scrCam;
  FForm:=form;
  fFps:=fps;
  FszFilename:=szFilename;
  FreeOnTerminate := True;
  inherited Create(False);
end;


{ The Execute method is called when the thread starts }
procedure TRecordAVIThread.Execute;
var
  res: integer;
begin
  repeat
    res:=FScrCam.recordVideo(FForm, FszFilename);
  until NOT(res = -1);
end;

procedure TRecordAVIThread.FlashPaintBorder;
begin
  if NOT FScrCam.recordState then exit;
  FScrCam.FFrame.PaintBorder(FlashCol);
end;

procedure TRecordAVIThread.FlashSetupRegion;
begin
  if NOT FScrCam.recordState then exit;
  FScrCam.FFrame.SetUpRegion(flashLeft, flashTop, flashWidth, flashHeight);
end;


end.

