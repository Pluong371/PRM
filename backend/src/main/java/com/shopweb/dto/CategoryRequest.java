package com.shopweb.dto;

import lombok.Data;

/**
 * DTO for creating/updating categories
 */
@Data
public class CategoryRequest {
    private String name;
    private String description;
    private Long parentId;
    private Boolean isActive;
}
