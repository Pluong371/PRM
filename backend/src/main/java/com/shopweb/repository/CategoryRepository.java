package com.shopweb.repository;

import com.shopweb.model.entity.Category;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Repository for Category entity
 */
@Repository
public interface CategoryRepository extends JpaRepository<Category, Long> {

    /**
     * Find all root categories (no parent)
     */
    List<Category> findByParentIsNull();

    /**
     * Find direct children of a category
     */
    List<Category> findByParent_Id(Long parentId);
}
