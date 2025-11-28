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

@WebMvcTest(PositionController.class)
class PositionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private PositionService positionService;

    private Position testPosition1;
    private Position testPosition2;
    private Position testPosition3;
    private List<Position> allPositions;
    private List<Position> positionsForAccount1;

    @BeforeEach
    void setUp() {
        // Setup test position 1 (Account 1, MSFT)
        testPosition1 = new Position();
        testPosition1.setAccountId(1);
        testPosition1.setSecurity("MSFT");
        testPosition1.setQuantity(100);
        testPosition1.setUpdated(new Date());

        // Setup test position 2 (Account 1, AAPL)
        testPosition2 = new Position();
        testPosition2.setAccountId(1);
        testPosition2.setSecurity("AAPL");
        testPosition2.setQuantity(50);
        testPosition2.setUpdated(new Date());

        // Setup test position 3 (Account 2, MSFT)
        testPosition3 = new Position();
        testPosition3.setAccountId(2);
        testPosition3.setSecurity("MSFT");
        testPosition3.setQuantity(200);
        testPosition3.setUpdated(new Date());

        // Setup all positions list
        allPositions = new ArrayList<>();
        allPositions.add(testPosition1);
        allPositions.add(testPosition2);
        allPositions.add(testPosition3);

        // Setup positions for account 1
        positionsForAccount1 = new ArrayList<>();
        positionsForAccount1.add(testPosition1);
        positionsForAccount1.add(testPosition2);
    }

    @Test
    void testGetAllPositions() throws Exception {
        // Arrange
        when(positionService.getAllPositions()).thenReturn(allPositions);

        // Act & Assert
        mockMvc.perform(get("/positions/")
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(3))
                .andExpect(jsonPath("$[0].accountId").value(1))
                .andExpect(jsonPath("$[0].security").value("MSFT"))
                .andExpect(jsonPath("$[0].quantity").value(100))
                .andExpect(jsonPath("$[1].accountId").value(1))
                .andExpect(jsonPath("$[1].security").value("AAPL"))
                .andExpect(jsonPath("$[1].quantity").value(50))
                .andExpect(jsonPath("$[2].accountId").value(2))
                .andExpect(jsonPath("$[2].security").value("MSFT"))
                .andExpect(jsonPath("$[2].quantity").value(200));
    }

    @Test
    void testGetPositionsByValidAccountId() throws Exception {
        // Arrange
        int validAccountId = 1;
        when(positionService.getPositionsByAccountID(validAccountId)).thenReturn(positionsForAccount1);

        // Act & Assert
        mockMvc.perform(get("/positions/" + validAccountId)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[0].accountId").value(1))
                .andExpect(jsonPath("$[0].security").value("MSFT"))
                .andExpect(jsonPath("$[0].quantity").value(100))
                .andExpect(jsonPath("$[1].accountId").value(1))
                .andExpect(jsonPath("$[1].security").value("AAPL"))
                .andExpect(jsonPath("$[1].quantity").value(50));
    }

    @Test
    void testGetPositionsByInvalidAccountId() throws Exception {
        // Arrange
        int invalidAccountId = 999;
        List<Position> emptyList = new ArrayList<>();
        when(positionService.getPositionsByAccountID(invalidAccountId)).thenReturn(emptyList);

        // Act & Assert
        // Note: The current implementation returns an empty list for invalid account IDs, not a 404
        mockMvc.perform(get("/positions/" + invalidAccountId)
                .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(0));
    }
}

