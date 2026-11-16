# Findings từ dữ liệu mô phỏng đã nạp SQL

Nguồn kiểm chứng: `outputs/sql_evidence/`, dữ liệu seed 42 kỳ 05–10/2026. Các tình huống được chủ động cài trong generator, không phải phát hiện trên nhà máy thật.

## 1. M003 cần được ưu tiên xem xét

- Finding: M003 đứng đầu downtime và có sự cố lặp lại.
- Evidence: 142,48 giờ downtime, 30 sự cố, MTBF 78,45 giờ/lần. Máy đứng thứ hai M005 có 33,94 giờ downtime.
- Interpretation: mẫu dữ liệu thể hiện một máy thường xuyên hỏng và cần thời gian sửa nhiều hơn.
- Recommendation: rà soát lịch sử sự cố với kỹ thuật viên, điều kiện vận hành và sự phù hợp của lịch bảo trì.
- Limitation: đây là kịch bản cố ý sinh; chưa có dữ liệu tải máy, phụ tùng hay chẩn đoán kỹ thuật.

## 2. Failure mode lặp lại ở M003

- Finding: Bearing wear xuất hiện lặp lại ở M003.
- Evidence: 30 sự kiện Corrective của M003 ghi cùng failure mode.
- Interpretation: danh mục nguyên nhân cần được kiểm tra trước khi kết luận vấn đề ổ trục cụ thể.
- Recommendation: chuẩn hóa cách ghi failure mode, đối chiếu với biên bản kỹ thuật; có thể bổ sung checklist bôi trơn/vệ sinh theo 5S/TPM sau xác minh.
- Limitation: nhãn mô phỏng không xác lập nguyên nhân cơ khí và không chứng minh lợi ích của một can thiệp.

## 3. PM compliance của L01 thấp hơn các line khác

- Finding: L01 có tỷ lệ hoàn thành đúng hạn thấp hơn.
- Evidence: 40/60 nhiệm vụ đúng hạn (66,67%); các line L02–L04 mỗi line 60/60 (100%). Toàn bộ 220/240 = 91,67%.
- Interpretation: trong kịch bản đã thiết kế, PM trễ đi cùng xu hướng Corrective tăng trên L01. Chưa có cơ sở suy ra quan hệ nhân quả.
- Recommendation: xem các nhiệm vụ quá hạn, phân công và năng lực theo lịch, sau đó mới cân nhắc điều chỉnh chu kỳ.
- Limitation: các line khác được mô phỏng lý tưởng; độ chênh không đại diện phân phối PM thực tế. Không tuyên bố giảm downtime hay tiết kiệm chi phí.
