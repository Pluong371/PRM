package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * StockAlert entity for Manager subsystem
 * Alerts for low stock levels
 */
@Entity
@Table(name = "stock_alerts")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class StockAlert {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "product_id")
    private Product product;
    
    @Column(nullable = false)
    private String alertType; // LOW_STOCK, OUT_OF_STOCK
    
    @Column(nullable = false)
    private String status; // ACTIVE, RESOLVED
    
    private Integer currentQuantity;
    
    private LocalDateTime createdAt;
    
    private LocalDateTime resolvedAt;
}
