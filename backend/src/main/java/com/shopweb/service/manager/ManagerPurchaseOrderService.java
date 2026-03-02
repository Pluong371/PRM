package com.shopweb.service.manager;

import com.shopweb.dto.PurchaseOrderDetailRequest;
import com.shopweb.dto.PurchaseOrderDetailResponse;
import com.shopweb.dto.PurchaseOrderRequest;
import com.shopweb.dto.PurchaseOrderResponse;
import com.shopweb.model.entity.*;
import com.shopweb.repository.ProductRepository;
import com.shopweb.repository.PurchaseOrderDetailRepository;
import com.shopweb.repository.PurchaseOrderRepository;
import com.shopweb.repository.SupplierRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@Service
public class ManagerPurchaseOrderService {

    @Autowired
    private PurchaseOrderRepository purchaseOrderRepository;

    @Autowired
    private PurchaseOrderDetailRepository purchaseOrderDetailRepository;

    @Autowired
    private SupplierRepository supplierRepository;

    @Autowired
    private ProductRepository productRepository;

    public List<Supplier> getAllSuppliers() {
        return supplierRepository.findAll();
    }

    @Transactional
    public PurchaseOrder createPurchaseOrder(PurchaseOrderRequest request) {
        if (request.getSupplierName() == null || request.getSupplierName().trim().isEmpty()) {
            throw new IllegalArgumentException("Supplier name is required");
        }

        Supplier supplier = supplierRepository.findByName(request.getSupplierName())
                .orElseGet(() -> {
                    Supplier s = new Supplier();
                    s.setName(request.getSupplierName());
                    return supplierRepository.save(s);
                });

        PurchaseOrder order = new PurchaseOrder();
        order.setSupplier(supplier);
        order.setOrderDate(LocalDateTime.now());
        order.setStatus(PurchaseOrderStatus.PENDING);
        order.setTotalAmount(BigDecimal.ZERO); // Will calculate later

        // Save parent first to get an ID for children
        PurchaseOrder savedOrder = purchaseOrderRepository.save(order);

        BigDecimal totalAmount = BigDecimal.ZERO;
        List<PurchaseOrderDetail> detailsToSave = new ArrayList<>();

        if (request.getDetails() != null) {
            for (PurchaseOrderDetailRequest itemReq : request.getDetails()) {
                Product product = productRepository.findById(itemReq.getProductId())
                        .orElseThrow(
                                () -> new IllegalArgumentException("Product not found: " + itemReq.getProductId()));

                PurchaseOrderDetail detail = new PurchaseOrderDetail();
                detail.setPurchaseOrder(savedOrder);
                detail.setProduct(product);
                detail.setQuantity(itemReq.getQuantity());
                detail.setUnitPrice(itemReq.getUnitPrice());

                // Keep running total: unitPrice * quantity
                BigDecimal itemTotal = itemReq.getUnitPrice().multiply(BigDecimal.valueOf(itemReq.getQuantity()));
                totalAmount = totalAmount.add(itemTotal);

                detailsToSave.add(detail);
            }
        }

        // Save all children
        purchaseOrderDetailRepository.saveAll(detailsToSave);

        // Update total amount on parent
        savedOrder.setTotalAmount(totalAmount);
        return purchaseOrderRepository.save(savedOrder);
    }

    public List<PurchaseOrderResponse> getAllPurchaseOrders() {
        return purchaseOrderRepository.findAll().stream()
                .sorted((o1, o2) -> o2.getOrderDate().compareTo(o1.getOrderDate())) // Descending by date
                .map(this::mapToResponse)
                .collect(Collectors.toList());
    }

    private PurchaseOrderResponse mapToResponse(PurchaseOrder order) {
        PurchaseOrderResponse response = new PurchaseOrderResponse();
        response.setId(order.getId());
        response.setSupplierName(order.getSupplier().getName());
        response.setOrderDate(order.getOrderDate());
        response.setTotalAmount(order.getTotalAmount());
        response.setStatus(order.getStatus().name());

        List<PurchaseOrderDetailResponse> detailResponses = order.getDetails().stream()
                .map(detail -> {
                    PurchaseOrderDetailResponse dr = new PurchaseOrderDetailResponse();
                    dr.setProductId(detail.getProduct().getId());
                    dr.setProductName(detail.getProduct().getName());
                    dr.setQuantity(detail.getQuantity());
                    dr.setUnitPrice(detail.getUnitPrice());
                    dr.setSubTotal(detail.getUnitPrice().multiply(BigDecimal.valueOf(detail.getQuantity())));
                    return dr;
                }).collect(Collectors.toList());

        response.setDetails(detailResponses);
        return response;
    }
}
