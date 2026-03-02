package com.shopweb.dto;

import jakarta.validation.constraints.Min;
import lombok.Data;
import java.math.BigDecimal;
import java.util.List;

@Data
public class ProductRequest {
    private String name;
    private String description;
    private BigDecimal price;
    private String brand;
    private String imageUrl;
    private Integer stockQuantity;
    @Min(value = 0, message = "Min stock level must not be negative")
    private Integer minStockLevel; // Ngưỡng tồn kho tối thiểu
    private List<Long> categoryIds; // Multiple category IDs
    private List<ProductAttributeDTO> attributes;
}