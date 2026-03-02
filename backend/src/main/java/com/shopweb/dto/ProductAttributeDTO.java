package com.shopweb.dto;

import lombok.Data;

@Data
public class ProductAttributeDTO {
    private String name;  // VD: "Màu sắc", "RAM"
    private String value; // VD: "Đen", "16GB"
}