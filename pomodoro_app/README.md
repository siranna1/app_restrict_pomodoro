# 部分禁欲ポモロード
ポモドーロタイマーで自分の作業時間を管理して、自分の作業時間に応じてゲームなどの利用時間を制御できます。徹底的に勉強するぞ


## 覚え書き
win32の命令で実装されてないやつがあったから自分で追加する
C:\Users\自分のユーザ名\AppData\Local\Pub\Cache\hosted\pub.dev\win32自分のバージョン\lib\src\win32\kernel32.g.dart
に
```
// CreateToolhelp32Snapshot の定義
typedef CreateToolhelp32SnapshotC = IntPtr Function(Uint32 dwFlags, Uint32 th32ProcessID);
typedef CreateToolhelp32SnapshotDart = int Function(int dwFlags, int th32ProcessID);

final CreateToolhelp32SnapshotDart CreateToolhelp32Snapshot =
    _kernel32.lookupFunction<CreateToolhelp32SnapshotC, CreateToolhelp32SnapshotDart>(
        'CreateToolhelp32Snapshot');
```
と
```
// Process32First の定義
typedef Process32FirstC = Int32 Function(IntPtr hSnapshot, Pointer<PROCESSENTRY32> lppe);
typedef Process32FirstDart = int Function(int hSnapshot, Pointer<PROCESSENTRY32> lppe);

final Process32FirstDart Process32First =
    _kernel32.lookupFunction<Process32FirstC, Process32FirstDart>('Process32FirstW');

// Process32Next の定義
typedef Process32NextC = Int32 Function(IntPtr hSnapshot, Pointer<PROCESSENTRY32> lppe);
typedef Process32NextDart = int Function(int hSnapshot, Pointer<PROCESSENTRY32> lppe);

final Process32NextDart Process32Next =
    _kernel32.lookupFunction<Process32NextC, Process32NextDart>('Process32NextW');  
```
を追加

C:\Users\自分のユーザ名\AppData\Local\Pub\Cache\hosted\pub.dev\win32-自分のバージョン\lib\src\structs.g.dart
に
```
// PROCESSENTRY32 構造体の定義
class PROCESSENTRY32 extends Struct {
  @Uint32()
  external int dwSize;

  @Uint32()
  external int cntUsage;

  @Uint32()
  external int th32ProcessID;

  @IntPtr()
  external int th32DefaultHeapID;

  @Uint32()
  external int th32ModuleID;

  @Uint32()
  external int cntThreads;

  @Uint32()
  external int th32ParentProcessID;

  @Int32()
  external int pcPriClassBase;

  @Uint32()
  external int dwFlags;

  @Array(260)
  external Array<Uint16> szExeFile; // プロセス名
}
```
を追加
C:\Users\自分のユーザ名\AppData\Local\Pub\Cache\hosted\pub.dev\win32-自分のバージョン\lib\src\constants.dart
に
```
// CreateToolhelp32Snapshot 用のフラグ
const int TH32CS_SNAPPROCESS = 0x00000002; // プロセススナップショット
const int TH32CS_SNAPTHREAD = 0x00000004;  // スレッドスナップショット
const int TH32CS_SNAPMODULE = 0x00000008;  // モジュールスナップショット
const int TH32CS_SNAPMODULE32 = 0x00000010; // 32-bit モジュールスナップショット
const int TH32CS_SNAPHEAPLIST = 0x00000001; // ヒープスナップショット
const int TH32CS_SNAPALL = TH32CS_SNAPPROCESS |
    TH32CS_SNAPTHREAD |
    TH32CS_SNAPMODULE |
    TH32CS_SNAPHEAPLIST;
```
を追加
全部したら多分動く
