# Mimic Slate

Bốn script riêng, cùng UI Slate và hệ thống ESP/Local Player. Ưu tiên điện thoại: sidebar thu gọn, vùng chạm lớn, control tự xuống dòng, ô nhập số trong slider và nút mở menu nổi. VFly giữ cách điều khiển mobile của cc: cần di chuyển kết hợp hướng camera, không có nút bay ngoài màn hình.

## Dùng ngay từ file

Chọn đúng một tệp trong thư mục gốc của gói:

| Tệp | Dùng cho |
| --- | --- |
| `Book1.lua` | Book 1, Chapter 1–4 |
| `Book2.lua` | Book 2, Chapter 1–4; Paintings đã nhúng |
| `Book3.lua` | Book 3, Chapter 1; Egao mới và Nearby Kill |
| `Gamemodes.lua` | Jigoku, Witch Trial, Halloween Trial và Egao |

1. Mở tệp tương ứng bằng chức năng mở file của executor, hoặc đưa nội dung tệp vào trình chạy.
2. Chạy trong chapter phù hợp. Mỗi bản tự tạo giao diện và các thành phần của mình; không cần loader 229/GG ban đầu.
3. Dùng `Chapter` / `Modes` cho tính năng màn hiện tại; `Visuals` cho ESP; `Local Player` cho di chuyển và ánh sáng.
4. Dùng nút `M` nổi để ẩn/hiện trên điện thoại. Các nút đóng/thu cửa sổ chỉ ẩn menu. Chọn `Overview → Unload` để dọn toàn bộ runtime.
5. `Stop chapter actions` dừng automation mà vẫn giữ lựa chọn chuyển động và hiển thị. Có thể bật tác vụ trở lại sau đó.

Các tệp gốc đã chứa UI nên không cần repo GitHub hoạt động để mở giao diện. Một runtime hoạt động tại một thời điểm; chạy bản Book khác sẽ dọn bản trước để tránh hai bộ điều khiển nhân vật chạy chồng nhau.

## Bản dùng UI GitHub raw riêng

Repo đã cấu hình: https://github.com/eystearisdown/wyattrz — nhánh `main`.

Trong gói có ba thư mục:

- `ui/SlateUI.lua`: thư viện giao diện dùng chung.
- `scripts/`: bốn script tải UI từ URL raw riêng; các thành phần logic còn lại đã được đóng gói, Paintings vẫn ở trong `scripts/Book2.lua`.
- `raw/`: bốn launcher ngắn để tải script tương ứng từ repo.

Đăng lên GitHub bằng trình duyệt:

1. Mở repo, chọn **Add file → Upload files**.
2. Tải nguyên hai thư mục `ui` và `scripts` lên **gốc repo**; giữ đúng tên thư mục và tên tệp, rồi commit vào `main`.
3. Mở file `raw/Book1.lua`, `raw/Book2.lua`, `raw/Book3.lua` hoặc `raw/Gamemodes.lua` trong gói và dùng launcher phù hợp.

Sau khi tải lên, cây repo cần có dạng:

```text
wyattrz/
├── ui/
│   └── SlateUI.lua
└── scripts/
    ├── Book1.lua
    ├── Book2.lua
    ├── Book3.lua
    └── Gamemodes.lua
```

URL UI được cấu hình là:

```text
https://raw.githubusercontent.com/eystearisdown/wyattrz/main/ui/SlateUI.lua
```

Ví dụ launcher Book 3, **chỉ dùng sau khi các file đã được tải lên đúng đường dẫn**:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/eystearisdown/wyattrz/main/scripts/Book3.lua"))()
```

Việc tách UI giảm khoảng 70 KB mã UI lặp trong mỗi script và giúp cập nhật giao diện ở một nơi. Nó không đảm bảo FPS cao hơn. UI dùng icon ký tự và các thành phần vẽ tích hợp; không tải bộ ảnh/font ngoài. Thư viện UI được khởi tạo mới mỗi lần để không giữ cửa sổ cũ.

Các URL trên là cấu hình xuất bản; gói này không tự đăng file lên GitHub. Tại lúc bàn giao, phiên GitHub trong môi trường làm việc không xác thực được token, nên chưa có commit nào được đẩy lên repo.

## Những gì đã thay đổi

- Giữ các handler Book 1/2/3 và mode có triển khai từ source 229, tách thành adapter riêng theo gói; sửa các lỗi task, nil guard, tên callback và phạm vi biến đã kiểm kê.
- ESP Slate chung: nhãn một dòng tên/khoảng cách, outline fill nhẹ, màu phân loại, giới hạn khoảng cách, ưu tiên mục tiêu gần, giảm nhãn chồng nhau, refresh mục tiêu spawn/stream muộn và cleanup tập trung.
- Local Player chung: VFly, TPWalk, Noclip, Moonwalk, Fullbright, Instant E. VFly giữ công thức điều khiển camera + cần di chuyển của cc trên mobile; tạm nhường quyền TPWalk/Moonwalk khi bay. Không đưa bộ WalkSpeed/JumpPower cũ vào UI.
- Book 2 chứa nguyên bộ Paintings mới: 4 mẫu, 5.916 bản ghi nét vẽ/trạng thái và đủ 4 pose. Không tải Paintings từ nơi khác.
- Book 3 có Nearby Kill lấy ý tưởng cc, giữ bộ lọc/range riêng và điều kiện nhìn FleshBlock. Không dùng teleport cho Nearby Kill; status phân biệt yêu cầu gửi đi với kết quả kill được xác nhận.
- Egao dùng file bổ sung mới, thay cho finder cũ: Lobby → Save 1 → Forest → kiểm tra Egao → quay lobby khi chưa có. Có Auto Look, Fullbright/No Fog tùy chọn, hop/time/ping/phase/reason và bảng trạng thái nổi kéo được khi menu ẩn. Gamemodes cũng dùng cùng adapter Egao.

## Egao: điều kiện và cách dùng

Save 1 của tài khoản cần ở Forest, giống yêu cầu của file Egao mới. Bật `Egao → Auto Find Egao`; bật/tắt Auto Look, ánh sáng/sương và thanh nổi trong cùng tab.

Tiếp tục tự động qua teleport cần executor hỗ trợ `queue_on_teleport` hoặc biến thể tương ứng. Runtime xếp hàng chính payload hiện tại cùng trạng thái tìm kiếm; bản chạy từ file vẫn dùng được khả năng này, không bắt buộc GitHub. Nếu không xếp hàng được, status sẽ tạm dừng trước khi bắt đầu chuyển màn. Stop cập nhật phiên hủy để ngăn một payload cũ tự bật tìm lại.

## Phạm vi kiểm tra và các phần còn thiếu của source

Đã kiểm tra ngoại tuyến bằng Luau chính thức: biên dịch module và payload, dữ liệu tranh so với nguồn, phân tách gói, UI mobile/status, các API core, dừng/chạy lại tác vụ, queue và khôi phục trạng thái bằng mock. Chưa chạy trong Roblox thực tế; chưa xác nhận đường dẫn object, remote, physics và hook của executor với bản game hiện tại.

`Auto Paint` của **Book 2 Chapter 1** vẫn được khóa và ghi rõ thiếu handler trong source 229. Dữ liệu Paintings người dùng bổ sung dành cho Drawing của **Chapter 4**; nó không cung cấp handler cho Chapter 1. Những tính năng khác phụ thuộc object/tool/tiến trình game sẽ báo lỗi hoặc trạng thái chờ thay vì báo hoàn thành giả.

`Instant E` giảm thời gian giữ prompt ở phía client; không tự bấm mọi prompt. Moonwalk là quay lưng theo camera như cc, không thay animation bước chân. UI và core mới được viết riêng; logic chapter/data bắt nguồn từ các tệp người dùng cung cấp.
