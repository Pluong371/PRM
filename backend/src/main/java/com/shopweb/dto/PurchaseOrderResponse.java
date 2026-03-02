package com.shopweb.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

@Data
public class PurchaseOrderResponse {
    private Long id;
    private String supplierName;
    private LocalDateTime orderDate;
    private BigDecimal totalAmount;
    private String status;
    private List<PurchaseOrderDetailResponse> details;
}
