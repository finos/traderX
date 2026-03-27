package finos.traderx.accountservice.controller;

import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.stereotype.Controller;

@Controller
public class DocsController {

    @RequestMapping("/")
    public String index() {
        return "redirect:swagger-ui.html";
    }
}
