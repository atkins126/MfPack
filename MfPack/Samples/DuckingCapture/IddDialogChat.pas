unit IddDialogChat;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  WinApi.WinMM.MMeApi,
  WinApi.WinMM.MMSysCom,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  ChatTransport;

// Global Variables:
const
  MAX_LOADSTRING = 100;

  //
  //  The current "Chat" transport.
  //
type
  ChatState = (ChatStatePlaying,    // We're currently playing/capturing
               ChatStateNotPlaying);

type
  TForm1 = class(TForm)
    btnChatStart: TButton;
    btnChatStop: TButton;
    butExit: TButton;
    GroupBox2: TGroupBox;
    GroupBox1: TGroupBox;
    cbxChatTransport: TComboBox;
    rbtCapture: TRadioButton;
    rbtRender: TRadioButton;
    chkHideFromVolumeMixer: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure butExitClick(Sender: TObject);
    procedure btnChatStartClick(Sender: TObject);
    procedure btnChatStopClick(Sender: TObject);
    procedure cbxChatTransportChange(Sender: TObject);
    procedure rbtCaptureClick(Sender: TObject);
  private
    { Private declarations }

    //  UI State information.
    g_WaveComboBoxIndex: Integer;
    g_WasapiComboBoxIndex: Integer;

    function IsWin7OrLater(): Boolean;
    procedure SyncUIState(State: ChatState);

  public
    { Public declarations }

    g_CurrentChat: CChatTransport;
    g_hInstance: HINST; // Current instance
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

uses
  WasapiChat,
  WaveChat;

//
//  This sample funtion only works on Windows 7
//  Note: seeL https://docs.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-verifyversioninfow
//
function TForm1.IsWin7OrLater(): Boolean;
var
  bWin7OrLater: Boolean;
  ver: OSVERSIONINFOEX;

begin
  bWin7OrLater := True;

  ver.dwOSVersionInfoSize := SizeOf(ver);
  // GetVersionEx is deprecated, after win7 we should use VerifyVersionInfo.
  if GetVersionEx(ver) then
    begin
      bWin7OrLater := (ver.dwMajorVersion > 6) or
                      ((ver.dwMajorVersion = 6) And (ver.dwMinorVersion >= 1));
    end;

  Result := bWin7OrLater;
end;

procedure TForm1.btnChatStartClick(Sender: TObject);
begin

  //
  //  Start the chat engine.
  //
  if g_CurrentChat.StartChat(chkHideFromVolumeMixer.Checked) then
    SyncUIState(ChatStatePlaying);
end;

procedure TForm1.btnChatStopClick(Sender: TObject);
begin
  //
  //  Stop the chat engine.
  //
  if Assigned(g_CurrentChat) then
    begin
      g_CurrentChat.StopChat();
      SyncUIState(ChatStateNotPlaying);
    end;
end;


procedure TForm1.butExitClick(Sender: TObject);
begin
  //
  //  Stop on Cancel/OK.
  //
  if Assigned(g_CurrentChat) then
    begin
      g_CurrentChat.StopChat();
      g_CurrentChat.Shutdown();
      g_CurrentChat.Free;
      g_CurrentChat := nil;
    end;
  Close; // EndDialog(hWnd, TRUE);
end;

procedure TForm1.cbxChatTransportChange(Sender: TObject);
var
  currentSel: Integer;
  useInputDevice: Boolean;

begin

  currentSel := cbxChatTransport.ItemIndex;

  //
  //  The user modified the chat transport. Delete the existing chat transport and create a new one.
  //
  g_CurrentChat.Shutdown();
  g_CurrentChat.Free;
  g_CurrentChat := nil;

  if (currentSel = g_WasapiComboBoxIndex) then
    begin
      //
      //  Instantiate the WASAPI transport.
      //
      g_CurrentChat := CWasapiChat.Create(Self.Handle);
      if not Assigned(g_CurrentChat) then
        begin
          MessageBox(Handle,
                     'Unable to create WASAPI chat transport',
                     'Error',
                     MB_OK);
        end;
      // Set the in or output device
      //g_CurrentChat.i
    end
  else if (currentSel = g_WaveComboBoxIndex) then
    begin
      //
      //  Instantiate the wave transport.
      //
      g_CurrentChat := CWaveChat.Create(Self.Handle);
      if not Assigned(g_CurrentChat) then
        begin
              MessageBox(Handle,
                         'Unable to create WAVE chat transport',
                         'Error',
                         MB_OK);
        end;
    end;

  //
  //  Sync the UI to the transport choice
  //
  SyncUIState(ChatStateNotPlaying);

  //
  //  Initialize the chat object
  //
  useInputDevice := rbtCapture.Checked;

  if g_CurrentChat.Initialize(useInputDevice) then
    //
    //  Sync the UI to the state again - we're not playing but after initializing the state might change.
    //
    SyncUIState(ChatStateNotPlaying)
  else
    MessageBox(Handle,
               'Unable to initialize chat',
               'Error',
               MB_OK);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin

  g_WaveComboBoxIndex := 0;
  g_WasapiComboBoxIndex := 1;

  if Not IsWin7OrLater() then
    begin
      if MessageBox(0,
                    'This sample requires Windows 7 or later',
                    'Incompatible OS Version',
                    MB_OK or MB_ICONSTOP) = ID_OK then
        Close;
    end;

  //
  //  Start by using the wave transport for "chat".
  //  Allocate the WAVE chat transport.  If we failed to startup, we're done.
  //
  g_CurrentChat := CWaveChat.Create(Self.Handle);

  if not Assigned(g_CurrentChat) then
    begin
      MessageBox(Handle,
                'Unable to allocate WAVE chat transport',
                'Startup Error',
                MB_OK);

        Close; // EndDialog(hWnd, TRUE);
    end;

  if Not g_CurrentChat.Initialize(true) then
    Close; // EndDialog(hWnd, TRUE);


  //
  //  Set up the combobox and initialize the chat options to reflect that we've set the Wave chat transport by default.
  //
  cbxChatTransport.Items.Append('WAVE API Transport');
  cbxChatTransport.Items.Append('WASAPI API Transport');
  cbxChatTransport.ItemIndex := g_WaveComboBoxIndex;

  //  Simulate a "stop" event to get the UI in sync.
  SyncUIState(ChatStateNotPlaying);
end;

//
//  Makes all of the dialog controls consistent with the current transport and specified chat state
//
procedure TForm1.SyncUIState({hWnd: HWND;} State: ChatState);
begin
  if (State = ChatStatePlaying) then
    begin
      //
      //  Sync the UI to the state - Since we're playing, the only thing we can do is to hit the "Stop" button.
      //
      btnChatStart.Enabled := False; //EnableWindow(GetDlgItem(hWnd, IDC_CHATSTART), FALSE);
      btnChatStop.Enabled := True;   // EnableWindow(GetDlgItem(hWnd, IDC_CHATSTOP), TRUE);
      cbxChatTransport.Enabled := False;  // EnableWindow(GetDlgItem(hWnd, IDC_COMBO_CHAT_TRANSPORT), FALSE);
      rbtCapture.Enabled := False;  // EnableWindow(GetDlgItem(hWnd, IDC_RADIO_CAPTURE), FALSE);
      rbtRender.Enabled := False;   // EnableWindow(GetDlgItem(hWnd, IDC_RADIO_RENDER), FALSE);
      chkHideFromVolumeMixer.Enabled := False;  // EnableWindow(GetDlgItem(hWnd, IDC_CHECK_HIDE_FROM_VOLUME_MIXER), FALSE);
    end
  else if (State = ChatStateNotPlaying) then
    begin
      //
      //  Sync the UI to the state - since we're not playing all the options except stop become available.
      //
      btnChatStart.Enabled := True;   // EnableWindow(GetDlgItem(hWnd, IDC_CHATSTART), TRUE);
      btnChatStop.Enabled := False;   // EnableWindow(GetDlgItem(hWnd, IDC_CHATSTOP), FALSE);
      cbxChatTransport.Enabled := True;  // EnableWindow(GetDlgItem(hWnd, IDC_COMBO_CHAT_TRANSPORT), TRUE);
      rbtCapture.Enabled := True;  // EnableWindow(GetDlgItem(hWnd, IDC_RADIO_CAPTURE), TRUE);

      //
      //  Now sync the transport options - the wave transport doesn't support output, so disable output device option
      //  when the the current transport is the wave transport.
      //
      //  Otherwise enable the "Use Output" and "hide from volume mixer" options
      //
      //  Note that the "Hide from volume mixer" option is only valid if the "Use Output Device" box is checked.
      //
      if Assigned(g_CurrentChat) and (g_CurrentChat.TransportType() = ChatTransportWave) then
        begin
          rbtRender.Enabled := False; //  EnableWindow(GetDlgItem(hWnd, IDC_RADIO_RENDER), FALSE);
          chkHideFromVolumeMixer.Enabled := False; //  EnableWindow(GetDlgItem(hWnd, IDC_CHECK_HIDE_FROM_VOLUME_MIXER), FALSE);
          rbtCapture.Checked := True; //  CheckDlgButton(hWnd, IDC_RADIO_CAPTURE, BST_CHECKED);
          rbtRender.Checked := False; // CheckDlgButton(hWnd, IDC_RADIO_RENDER, BST_UNCHECKED);
          chkHideFromVolumeMixer.Checked := False; // CheckDlgButton(hWnd, IDC_CHECK_HIDE_FROM_VOLUME_MIXER, BST_UNCHECKED);
        end
      else
        begin
          rbtRender.Enabled := True;  // EnableWindow(GetDlgItem(hWnd, IDC_RADIO_RENDER), TRUE);
          chkHideFromVolumeMixer.Enabled := rbtRender.Checked; //  EnableWindow(GetDlgItem(hWnd, IDC_CHECK_HIDE_FROM_VOLUME_MIXER), IsDlgButtonChecked(hWnd, IDC_RADIO_RENDER) == BST_CHECKED);
        end;
    end;
end;

// NOTE: This method is also used by rbtRender (see: rbtRender.OnClick)
procedure TForm1.rbtCaptureClick(Sender: TObject);
var
  currentSel: Integer;

begin
  currentSel := cbxChatTransport.ItemIndex;
  //
  //  The radio button selection may change when the transport is changed to Wave because render is not
  //  an option for Wave. We detect that here and only rebuild the transport for Wasapi
  //
  if ((currentSel = g_WasapiComboBoxIndex) and (g_CurrentChat.TransportType() = ChatTransportWasapi)) then
    begin

      //
      //  The user switched between render and capture. Delete the existing chat transport and create a new one.
      //
      g_CurrentChat.Shutdown();
      g_CurrentChat.Free;
      g_CurrentChat := Nil;

      //
      //  Reinstantiate the WASAPI transport.
      //
      //  Also update the state of the rendering options since the WASAPI transport supports them.
      //
      g_CurrentChat := CWasapiChat.Create(Self.Handle);
      if not Assigned(g_CurrentChat) then
        MessageBox(Self.Handle,
                   'Unable to create WASAPI chat transport',
                   'Error',
                   MB_OK)
      else if g_CurrentChat.Initialize(chkHideFromVolumeMixer.Checked) = False then
        MessageBox(Self.Handle,
                   'Unable to initialize chat',
                   'Error',
                   MB_OK);

      //
      //  Sync the UI to the state again - we're not playing but after initializing the state might change.
      //
      SyncUIState(ChatStateNotPlaying)
    end;
end;

end.
