package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * ProductItem entity
 * Represents individual items with serial numbers for high-value products
 */
@Entity
@Table(name = "product_items")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProductItem {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "product_id")
    private Product product;
    
    @Column(nullable = false, unique = true)
    private String serialNumber;
    
    @Column(nullable = false)
    private String status; // AVAILABLE, RESERVED, SOLD
    
    @ManyToOne
    @JoinColumn(name = "order_item_id")
    private OrderItem orderItem;
}
