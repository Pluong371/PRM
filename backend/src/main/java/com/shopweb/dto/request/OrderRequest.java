package com.shopweb.dto.request;

import lombok.Data;
import java.util.List;

@Data
public class OrderRequest {
  private String receiverName;
  private String receiverPhone;
  private String shippingAddress;
  private String note;
  private String paymentMethod;
  private String paymentProofUrl; // URL ảnh bill (chỉ dùng với QR_CODE)
  private List<OrderItemRequest> items;
}
