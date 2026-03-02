/*
 * Click nbfs://nbhost/SystemFileSystem/Templates/Licenses/license-default.txt to change this license
 * Click nbfs://nbhost/SystemFileSystem/Templates/Classes/Class.java to edit this template
 */
package com.shopweb.dto.staff;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderItemDTO {
    private Long id;
    //product info
    private Long productId;
    private String productName;
    private String productModel;
    private String productBrand;
    private String productImage;
    //product item info
    private Integer quantity;
    private BigDecimal priceAtPurchase;
    private BigDecimal price;
    private BigDecimal subtotal;
}
