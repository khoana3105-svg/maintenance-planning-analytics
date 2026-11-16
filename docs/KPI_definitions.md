# KPI và phạm vi

Tất cả dữ liệu là mô phỏng. Kỳ quan sát 01/05–31/10/2026; snapshot PM ngày 31/10/2026. Dữ liệu được thiết kế để luyện phân tích; không phải kết quả của Bosch.

| KPI | Định nghĩa |
|---|---|
| Downtime | Tổng Downtime_Hours không kế hoạch từ sự kiện Corrective hợp lệ, theo ngày sự kiện |
| Breakdown Count | Số sự kiện Corrective đã hoàn thành. Phiên bản này định nghĩa mọi Corrective là một sự cố hỏng, không gồm sửa khắc phục không gây sự cố |
| MTTR | Tổng Duration_Hours của Corrective / số sự kiện Corrective hợp lệ |
| MTBF | (Giờ sản xuất kế hoạch − downtime không kế hoạch) / số sự cố |
| PM compliance | PM Completed có Completed_Date ≤ Due_Date / PM đến hạn trong kỳ đã chọn, loại Cancelled và due date sau snapshot |

Đơn vị MTTR/MTBF là giờ/lần; downtime là giờ; compliance là tỷ lệ. Mẫu số 0 trả NULL/BLANK. Không lấy trung bình MTBF/MTTR từng máy để tính tổng: cộng tử và mẫu rồi chia.

Lịch giả định: 2 ca × 8 giờ × 26 ngày/tháng = 416 giờ/máy-tháng; 6 tháng = 2.496 giờ/máy. Với bộ lọc ngày tùy ý, gán 16 giờ cho ngày 1–26 mỗi tháng và 0 cho các ngày còn lại. Mọi máy được giả định có mặt suốt kỳ. Thời gian này không trừ downtime kế hoạch. Vì thế MTBF là ước lượng theo policy mô phỏng, không phải phép đo kỹ thuật thực tế.

Grain: 1 dòng máy = 1 máy; 1 maintenance = 1 hoạt động hoàn thành; 1 PM = 1 lần đến hạn. Bảng maintenance và PM không JOIN trực tiếp, tránh nhân bản sự kiện.

Các PM Daily/Weekly/Monthly là mẫu nhiệm vụ theo loại, không phải một lịch bao phủ tất cả ngày/tuần. PM đã hoàn thành được liên kết logic với một sự kiện Preventive cùng máy/ngày trong dữ liệu sinh. Chưa có khóa work order để theo dõi một sự kiện qua nhiều trạng thái.

Duplicate: giữ lần xuất hiện đầu, cách ly các lần tiếp theo, kể cả nếu bản đầu không hợp lệ. Không tự đoán bản nào đúng. Raw_Record và Source_Row giúp rà soát. Whitespace ở CSV được trim rõ ràng; không tự đổi tên category hoặc điền dữ liệu thiếu.

Schema ba CSV không có StartTime/EndTime; chỉ kiểm tra downtime tổng hợp không âm. Kiểm tra khoảng thời gian đảo chiều/chồng lấn thuộc phiên bản cũ, không thể suy ra từ schema mới. Nếu sau này bổ sung interval thì cần kiểm tra trước khi tổng hợp.
