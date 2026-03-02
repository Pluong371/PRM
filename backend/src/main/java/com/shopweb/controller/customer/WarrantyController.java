package com.shopweb.controller.customer;

import com.shopweb.dto.response.WarrantyResponse;
import com.shopweb.service.customer.WarrantyService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/warranty")
public class WarrantyController {

    @Autowired
    private WarrantyService warrantyService;

    @GetMapping("/check")
    public ResponseEntity<WarrantyResponse> checkWarranty(@RequestParam String serial) {
        WarrantyResponse response = warrantyService.checkWarrantyBySerial(serial);
        return ResponseEntity.ok(response);
    }
}