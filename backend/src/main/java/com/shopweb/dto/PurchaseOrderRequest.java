package com.shopweb.dto;

import lombok.Data;

import java.util.List;

@Data
public class PurchaseOrderRequest {
    private String supplierName;
    private List<PurchaseOrderDetailRequest> details;
}
