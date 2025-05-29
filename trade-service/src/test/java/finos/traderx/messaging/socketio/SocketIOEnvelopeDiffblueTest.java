package finos.traderx.messaging.socketio;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import com.diffblue.cover.annotations.MethodsUnderTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Tag;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;

@ContextConfiguration(classes = {SocketIOEnvelope.class})
@ExtendWith(SpringExtension.class)
class SocketIOEnvelopeDiffblueTest {
  @Autowired
  private SocketIOEnvelope<Object> socketIOEnvelope;

  /**
   * Test getters and setters.
   * <p>
   * Methods under test:
   * <ul>
   *   <li>{@link SocketIOEnvelope#SocketIOEnvelope()}
   *   <li>{@link SocketIOEnvelope#setFrom(String)}
   *   <li>{@link SocketIOEnvelope#setPayload(Object)}
   *   <li>{@link SocketIOEnvelope#setTopic(String)}
   *   <li>{@link SocketIOEnvelope#setType(String)}
   *   <li>{@link SocketIOEnvelope#getDate()}
   *   <li>{@link SocketIOEnvelope#getFrom()}
   *   <li>{@link SocketIOEnvelope#getPayload()}
   *   <li>{@link SocketIOEnvelope#getTopic()}
   *   <li>{@link SocketIOEnvelope#getType()}
   * </ul>
   */
  @Test
  @DisplayName("Test getters and setters")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void SocketIOEnvelope.<init>()", "java.util.Date SocketIOEnvelope.getDate()",
      "String SocketIOEnvelope.getFrom()", "Object SocketIOEnvelope.getPayload()", "String SocketIOEnvelope.getTopic()",
      "String SocketIOEnvelope.getType()", "void SocketIOEnvelope.setFrom(String)",
      "void SocketIOEnvelope.setPayload(Object)", "void SocketIOEnvelope.setTopic(String)",
      "void SocketIOEnvelope.setType(String)"})
  void testGettersAndSetters() {
    // Arrange and Act
    SocketIOEnvelope<Object> actualSocketIOEnvelope = new SocketIOEnvelope<>();
    actualSocketIOEnvelope.setFrom("jane.doe@example.org");
    actualSocketIOEnvelope.setPayload("Payload");
    actualSocketIOEnvelope.setTopic("Topic");
    actualSocketIOEnvelope.setType("Type");
    actualSocketIOEnvelope.getDate();
    String actualFrom = actualSocketIOEnvelope.getFrom();
    Object actualPayload = actualSocketIOEnvelope.getPayload();
    String actualTopic = actualSocketIOEnvelope.getTopic();

    // Assert
    assertEquals("Payload", actualPayload);
    assertEquals("Topic", actualTopic);
    assertEquals("Type", actualSocketIOEnvelope.getType());
    assertEquals("jane.doe@example.org", actualFrom);
  }

  /**
   * Test {@link SocketIOEnvelope#SocketIOEnvelope(String, Object)}.
   * <p>
   * Method under test: {@link SocketIOEnvelope#SocketIOEnvelope(String, Object)}
   */
  @Test
  @DisplayName("Test new SocketIOEnvelope(String, Object)")
  @Tag("MaintainedByDiffblue")
  @MethodsUnderTest({"void SocketIOEnvelope.<init>(String, Object)"})
  void testNewSocketIOEnvelope() {
    // Arrange and Act
    SocketIOEnvelope<Object> actualSocketIOEnvelope = new SocketIOEnvelope<>("Topic", "Payload");

    // Assert
    assertEquals("Payload", actualSocketIOEnvelope.getPayload());
    assertEquals("String", actualSocketIOEnvelope.getType());
    assertEquals("Topic", actualSocketIOEnvelope.getTopic());
    assertNull(actualSocketIOEnvelope.getFrom());
  }
}
