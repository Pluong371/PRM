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
import java.time.LocalDateTime;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderDetailDTO {
    private Long id;
    
    //customer info
    private CustomerInfoDTO customer;
    
    //order info
    private BigDecimal totalPrice;
    private String status;
    private Boolean hasInstallation;
    private String shippingAddress;
    private LocalDateTime createdAt;
    
    //order item list
    private List<OrderItemDTO> items;
}
