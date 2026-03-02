package com.shopweb.controller.manager;

import com.shopweb.dto.PurchaseOrderRequest;
import com.shopweb.dto.PurchaseOrderResponse;
import com.shopweb.model.entity.PurchaseOrder;
import com.shopweb.model.entity.Supplier;
import com.shopweb.service.manager.ManagerPurchaseOrderService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/manager")
public class ManagerPurchaseOrderController {

    @Autowired
    private ManagerPurchaseOrderService service;

    @GetMapping("/suppliers")
    public ResponseEntity<List<Supplier>> getAllSuppliers() {
        return ResponseEntity.ok(service.getAllSuppliers());
    }

    @PostMapping("/purchase-orders")
    public ResponseEntity<PurchaseOrder> createPurchaseOrder(@RequestBody PurchaseOrderRequest request) {
        PurchaseOrder created = service.createPurchaseOrder(request);
        return ResponseEntity.ok(created);
    }

    @GetMapping("/purchase-orders")
    public ResponseEntity<List<PurchaseOrderResponse>> getAllPurchaseOrders() {
        return ResponseEntity.ok(service.getAllPurchaseOrders());
    }
}
