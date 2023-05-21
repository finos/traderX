import { SetStateAction, useEffect, useState } from "react";

export const GetPeople = () => {
	const [people, setPeople] = useState<JSON[]>([]);
	type data = () => Promise<unknown>;
  useEffect(() => {
		let json:SetStateAction<JSON[]>;
    const loadPeople:data = async () => {
			try {
				const response = await fetch("http://127.0.0.1:18095/People/");
				if (response.ok) {
					json = await response.json();
					setPeople(json);
				}
			} catch (error) {
				return error;
			}
    }
    loadPeople();
  }, []);
	return people;
}