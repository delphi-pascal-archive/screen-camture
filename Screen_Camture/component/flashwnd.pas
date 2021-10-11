unit flashwnd;

interface

uses  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;


type
  TFlashingWnd = class(TCustomForm)
    private
      { Private declarations }
    	cRect: TRect;
     	oldregion: HRGN;
    protected
      { Protected declarations }
      procedure CreateParams(var Params: TCreateParams); override;
      //procedure WMpaint(var Message: TWMpaint); message WM_paint;
      //procedure WMdestroy(var Message: Tmessage); message WM_destroy;
    public
      { Public declarations }
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure SetUpRegion(x, y, width, height: integer);
      procedure PaintBorder(colorval: COLORREF);
  end;

implementation

const
  THICKNESS = 8;
  SMALLTHICKNESS = 4;
  SIDELEN = 12;
  SIDELEN2 = 24;


constructor TFlashingWnd.create(AOwner: TComponent);
begin
  inherited createNew(AOwner);
  borderstyle:=bsnone;
  top:=104;
  left:=430;
  ctl3d:=false;
  height:=458;
  width:=483;
  brush.style:=bsclear;
  controlstyle:=[csNoStdEvents];
  oldregion:=0;
end;

destructor TFlashingWnd.destroy;
begin
  if oldregion <> 0 then deleteObject(oldregion);
  inherited destroy;  
end;

procedure TFlashingWnd.CreateParams(var Params: TCreateParams);
begin
    inherited CreateParams(Params);
    {makes the window stay on top}
    params.exstyle:=params.exstyle or ws_ex_topmost;
    {makes the window that holds the origin icon captionless and borderless}
    params.style:=params.style or ws_popup;
end;


// Set the Window Region for transparancy outside the mask region
procedure TFlashingWnd.SetUpRegion(x, y, width, height: integer);
var
	wndRgn, rgnTemp, rgnTemp2,rgnTemp3, windowrgn, holergn: HRgn;
begin
  self.left:=x-THICKNESS;
  self.top:=y-THICKNESS;
  self.width:=width+2*THICKNESS;
  self.height:=height+2*THICKNESS;
	cRect.left:= x;
	cRect.top:= y;
	cRect.right := cRect.left + width -1;
	cRect.bottom := cRect.top + height -1;

  wndRgn:=CreateRectRgn(0,0, (cRect.right-cRect.left+1)+THICKNESS+THICKNESS, (cRect.bottom-cRect.top+1)+THICKNESS+THICKNESS);
	rgnTemp:=CreateRectRgn(THICKNESS, THICKNESS, (cRect.right-cRect.left+1)+THICKNESS+1, (cRect.bottom-cRect.top+1)+THICKNESS+1);
	rgnTemp2:=CreateRectRgn(0, SIDELEN2, (cRect.right-cRect.left+1)+THICKNESS+THICKNESS, (cRect.bottom-cRect.top+1)-SIDELEN+1);
	rgnTemp3:=CreateRectRgn(SIDELEN2,0, (cRect.right-cRect.left+1)-SIDELEN+1, (cRect.bottom-cRect.top+1)+THICKNESS+THICKNESS);

	CombineRgn(wndRgn, wndRgn, rgnTemp,RGN_DIFF);
	CombineRgn(wndRgn, wndRgn, rgnTemp2,RGN_DIFF);
	CombineRgn(wndRgn, wndRgn, rgnTemp3,RGN_DIFF);

	//OffsetRgn(wndRgn, {cRect.left}-THICKNESS, {cRect.top}-THICKNESS );

	SetWindowRgn(handle, wndRgn, TRUE);

  deleteObject(rgnTemp);
  deleteObject(rgnTemp2);
  deleteObject(rgnTemp3);

	if (oldregion <>0) then DeleteObject(oldregion);
	oldregion := wndRgn;

end;

(*procedure TFlashingWnd.wmpaint(var message: TWMPaint);
var
  dc: HDC;
  newbrush, newpen, oldbrush, oldpen: HBRUSH;
  ps: tpaintstruct;
  colorval: COLORREF;
begin
  colorval:=RGB(255,255,180);
  //dc := GetDC(handle);
  dc:=beginpaint(handle, ps);
	if ((cRect.right>cRect.left) AND (cRect.bottom>cRect.top)) then
  begin
		newbrush := CreateSolidBrush( colorval);
		newpen := CreatePen(PS_SOLID,1, colorval);
		oldbrush := SelectObject(dc, newbrush);
		oldpen := SelectObject(dc,newpen);

		Rectangle(dc,cRect.left-THICKNESS,cRect.top-THICKNESS,cRect.right+THICKNESS,cRect.bottom+THICKNESS);

		SelectObject(dc,oldpen);
		SelectObject(dc,oldbrush);
		DeleteObject(newpen);
		DeleteObject(newbrush);
  end;
	//ReleaseDC(handle,dc);
  endpaint(handle, ps);
end;

procedure TFlashingWnd.WMdestroy(var Message: Tmessage);
begin
  close;
end;

*)


procedure TFlashingWnd.PaintBorder(colorval: COLORREF);
var
  dc: HDC;
  newbrush, newpen, oldbrush, oldpen: HBRUSH;
  ps: tpaintstruct;
begin
  dc := GetDC(handle);
  //dc:=beginpaint(handle, ps);
	if ((cRect.right>cRect.left) AND (cRect.bottom>cRect.top)) then
  begin
		newbrush := CreateSolidBrush( colorval);
		newpen := CreatePen(PS_SOLID,1, colorval);
		oldbrush := SelectObject(dc, newbrush);
		oldpen := SelectObject(dc,newpen);

    windows.Rectangle(dc,0,0,cRect.right,cRect.bottom);
		//Rectangle(dc,cRect.left-THICKNESS,cRect.top-THICKNESS,cRect.right+THICKNESS,cRect.bottom+THICKNESS);

		SelectObject(dc,oldpen);
		SelectObject(dc,oldbrush);
		DeleteObject(newpen);
		DeleteObject(newbrush);
  end;
	ReleaseDC(handle,dc);
  //endpaint(handle, ps);
end;



end.
