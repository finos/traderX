package finos.traderx.positionservice.model;

import java.io.Serial;
import java.io.Serializable;
import java.util.Date;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

@Entity
@IdClass(PositionID.class)
@Table(name = "POSITIONS")
public class Position implements Serializable {


    @Serial
    private static final long serialVersionUID = 1L;

	@Id
	@Column(name = "ACCOUNTID")
	private Integer accountId;

	public Integer getAccountId() {
		return this.accountId;
	}

	public void setAccountId(Integer id) {
		this.accountId = id;
	}

	@Id
	@Column(length = 50, name = "SECURITY")
	private String security;

	public String getSecurity() {
		return this.security;
	}

	public void setSecurity(String security) {
		this.security = security;
	}

	@Column(name = "QUANTITY")
	private Integer quantity;

	public Integer getQuantity() {
		return this.quantity;
	}

	public void setQuantity(Integer quantity) {
		this.quantity = quantity;
	}

	@Column(name = "UPDATED")
	private Date updated;

	public void setUpdated(Date u){
		this.updated=u;
	}

	public Date getUpdated(){
		return this.updated;
	}
}
