package com.shopweb.controller.customer;

import com.shopweb.model.entity.CartItem;
import com.shopweb.model.entity.dto.AddToCartRequest;
import com.shopweb.service.customer.CustomerCartService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Controller for shopping cart management
 */
@RestController
@RequestMapping("/api/customer/cart")
@RequiredArgsConstructor
public class CustomerCartController {

    private final CustomerCartService cartService;

    @GetMapping
    public ResponseEntity<List<CartItem>> getCart(Authentication authentication) {
        String username = authentication.getName();
        return ResponseEntity.ok(cartService.getCartItems(username));
    }

    @PostMapping("/items")
    public ResponseEntity<List<CartItem>> addToCart(
            Authentication authentication,
            @RequestBody AddToCartRequest request) {
        String username = authentication.getName();
        return ResponseEntity.ok(cartService.addToCart(username, request.getProductId(), request.getQuantity()));
    }

    @PutMapping("/items/{id}")
    public ResponseEntity<List<CartItem>> updateCartItem(
            Authentication authentication,
            @PathVariable Long id,
            @RequestBody Map<String, Integer> request) {
        String username = authentication.getName();
        Integer quantity = request.get("quantity");
        if (quantity == null) {
            throw new IllegalArgumentException("Quantity is required");
        }
        return ResponseEntity.ok(cartService.updateCartItem(username, id, quantity));
    }

    @DeleteMapping("/items/{id}")
    public ResponseEntity<List<CartItem>> removeCartItem(
            Authentication authentication,
            @PathVariable Long id) {
        String username = authentication.getName();
        return ResponseEntity.ok(cartService.removeFromCart(username, id));
    }
}
