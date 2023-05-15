package finos.traderx.accountservice.model;

public class Person {

	private String logonId;
	private String fullName;
	private String email;
	private String department;
	private String photoUrl;

	public String getLogonId() {
		return this.logonId;
	}
	public void setLogonId(String logonId) {
		this.logonId = logonId;
	}
	public String getFullName() {
		return this.fullName;
	}
	public void setFullName(String fullName) {
		this.fullName = fullName;
	}
	public String getEmail() {
		return this.email;
	}
	public void setEmail(String email) {
		this.email = email;
	}
	public String getDepartment() {
		return this.department;
	}
	public void setDepartment(String department) {
		this.department = department;
	}
	public String getPhotoUrl() {
		return this.photoUrl;
	}
	public void setPhotoUrl(String photoUrl) {
		this.photoUrl = photoUrl;
	}

	@Override
	public String toString() {
		return "Person: " + this.logonId + " | " + this.fullName + " | " + this.email + " | " + this.department + " |";
	}

}
