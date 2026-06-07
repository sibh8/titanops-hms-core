package com.medicore.hms.lab.repository;
import com.medicore.hms.lab.model.LabOrder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
@Repository
public interface LabOrderRepository extends JpaRepository<LabOrder, Long> {
    List<LabOrder> findByPatientId(Long patientId);
    List<LabOrder> findByStatus(String status);
}
