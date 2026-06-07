package com.medicore.hms.provider.repository;
import com.medicore.hms.provider.model.Provider;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface ProviderRepository extends JpaRepository<Provider, Long> {
    List<Provider> findByActive(Boolean active);
}
