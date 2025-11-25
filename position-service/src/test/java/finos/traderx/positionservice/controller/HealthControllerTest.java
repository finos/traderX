package finos.traderx.positionservice.controller;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.ArrayList;
import java.util.Date;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import finos.traderx.positionservice.model.Position;
import finos.traderx.positionservice.service.PositionService;

import static org.mockito.Mockito.when;

@WebMvcTest(HealthController.class)
class HealthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PositionService positionService;

    private List<Position> positionsWithData;
    private List<Position> emptyPositions;

    @BeforeEach
    void setUp() {
        // Setup positions list with data (for ready check)
        positionsWithData = new ArrayList<>();
        Position position = new Position();
        position.setAccountId(1);
        position.setSecurity("MSFT");
        position.setQuantity(100);
        position.setUpdated(new Date());
        positionsWithData.add(position);

        // Setup empty positions list (for ready check when no data)
        emptyPositions = new ArrayList<>();
    }

    @Test
    void testHealthCheckAlive() throws Exception {
        // Act & Assert
        // The alive endpoint always returns true and doesn't depend on any service
        mockMvc.perform(get("/health/alive")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").value(true));
    }

    @Test
    void testHealthCheckReadyWithData() throws Exception {
        // Arrange
        // Mock service to return positions (ready = true when positions exist)
        when(positionService.getAllPositions()).thenReturn(positionsWithData);

        // Act & Assert
        mockMvc.perform(get("/health/ready")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").value(true));
    }

    @Test
    void testHealthCheckReadyWithoutData() throws Exception {
        // Arrange
        // Mock service to return empty list (ready = false when no positions exist)
        when(positionService.getAllPositions()).thenReturn(emptyPositions);

        // Act & Assert
        mockMvc.perform(get("/health/ready")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").value(false));
    }
}

