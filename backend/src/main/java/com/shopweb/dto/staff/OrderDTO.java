
package com.shopweb.dto.staff;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderDTO {
    private Long id;
    
    private Long customerId;
    private String customerName;
    private String customerEmail; 
    
    private BigDecimal totalPrice;
    private String status;
    private Boolean hasInstallation;
    private String shippingAddress;
    private LocalDateTime createdAt;
    
    private Integer totalItems;
}
