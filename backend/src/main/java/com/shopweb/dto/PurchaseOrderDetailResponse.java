package com.shopweb.dto;

import lombok.Data;
import java.math.BigDecimal;

@Data
public class PurchaseOrderDetailResponse {
    private Long productId;
    private String productName;
    private Integer quantity;
    private BigDecimal unitPrice;
    private BigDecimal subTotal;
}
