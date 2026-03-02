package com.shopweb.controller.manager;

import org.springframework.web.bind.annotation.*;

/**
 * Controller for manager stock control
 */
@RestController
@RequestMapping("/api/manager/stock")
public class ManagerStockController {
    
    // GET /api/manager/stock - Get all stock
    // GET /api/manager/stock/alerts - Get stock alerts
    // PUT /api/manager/stock/{id} - Update stock quantity
    // POST /api/manager/stock/alerts/{id}/resolve - Resolve alert
    // GET /api/manager/stock/reports - Get inventory reports for approval
    // PUT /api/manager/stock/reports/{id}/approve - Approve inventory report
    // PUT /api/manager/stock/reports/{id}/reject - Reject inventory report
}
