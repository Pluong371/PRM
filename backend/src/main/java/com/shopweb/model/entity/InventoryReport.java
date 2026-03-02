package com.shopweb.model.entity;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * InventoryReport entity for Staff subsystem
 * Reports for inventory discrepancies
 */
@Entity
@Table(name = "inventory_reports")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class InventoryReport {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne
    @JoinColumn(name = "product_id")
    private Product product;
    
    @ManyToOne
    @JoinColumn(name = "reported_by")
    private User reportedBy;
    
    @Column(nullable = false)
    private Integer expectedQuantity;
    
    @Column(nullable = false)
    private Integer actualQuantity;
    
    private String reason;
    
    @Column(nullable = false)
    private String status; // PENDING, APPROVED, REJECTED
    
    private LocalDateTime reportedAt;
    
    @ManyToOne
    @JoinColumn(name = "reviewed_by")
    private User reviewedBy;
    
    private LocalDateTime reviewedAt;
}
