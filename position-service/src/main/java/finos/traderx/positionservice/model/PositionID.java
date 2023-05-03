package finos.traderx.positionservice.model;

import java.io.Serializable;

public class PositionID implements Serializable {
	private Integer accountId;
	private String security;

	public PositionID() {
		// Entity
	}

	public PositionID(Integer accountId, String security) {
			this.accountId = accountId;
			this.security = security;
	}
}
