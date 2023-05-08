package finos.traderx.positionservice.controller;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
public class DocsController {

    @RequestMapping("/")
    public String index() {
        return "redirect:swagger-ui.html";
    }
}
