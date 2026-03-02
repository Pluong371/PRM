package com.shopweb.dto;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class PurchaseOrderDetailRequest {
    private Long productId;
    private Integer quantity;
    private BigDecimal unitPrice;
}
