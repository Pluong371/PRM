package com.shopweb.repository;

import com.shopweb.model.entity.Product;
import com.shopweb.model.entity.ProductAttribute;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface ProductAttributeRepository extends JpaRepository<ProductAttribute, Long> {
    // Hàm này để xóa các thuộc tính cũ của Product
    void deleteByProduct(Product product);

    // Hàm này để tìm kiếm (nếu cần)
    List<ProductAttribute> findByProduct(Product product);
}