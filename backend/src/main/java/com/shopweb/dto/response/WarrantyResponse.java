package com.shopweb.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class WarrantyResponse {
    private String productName;
    private String serialNumber;

    @JsonProperty("warrantyEndDate")   // ép JSON trả về camelCase
    private LocalDateTime warrantyEndDate;

    private String status; // VALID / EXPIRED
}