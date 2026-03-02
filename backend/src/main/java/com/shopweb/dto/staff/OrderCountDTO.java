package com.shopweb.dto.staff;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class OrderCountDTO {
    private Long total;       // tổng theo filter hiện tại
    private Long created;     // theo từng status
    private Long paid;
    private Long confirmed;
    private Long shipping;
    private Long failed;
    private Long refunded;
    private Long delivered;
    private Long completed;  
    private Long cancelled;
}
