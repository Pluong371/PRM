package com.shopweb.model.enums;

public enum OrderStatus {
  CREATED, // Mới tạo, chưa xác nhận
  PENDING, // Chờ xử lý (cả COD lẫn QR chưa xác nhận)
  PROCESSING, // Đang chuẩn bị hàng
  SHIPPING, // Đang giao hàng
  SHIPPED,
  DELIVERED, // Đã giao thành công
  COMPLETED, // Hoàn thành (đã nhận + đánh giá)
  CANCELLED, // Đã huỷ
  FAILED, // Thất bại
  REFUNDED, // Hoàn tiền
  PAID, // Đã thanh toán (QR confirmed)
  CONFIRMED // Admin đã xác nhận
}
