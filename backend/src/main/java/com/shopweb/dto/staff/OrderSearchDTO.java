package com.shopweb.dto.staff;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderSearchDTO {
    
    // keyword search: id, tên KH, email
    private String keyword;
    
    // filter theo status (null = tất cả)
    private String status;

    private String searchField = "id";
    
    // sort field: "id", "createdAt", "totalPrice"
    private String sortBy = "id";
    
    // sort direction: "asc", "desc"
    private String sortDir = "asc";
    
    // phân trang
    private int page = 0;
    private int size = 10;
}
