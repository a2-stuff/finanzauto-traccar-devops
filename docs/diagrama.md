# Diagrama de ambientes Dev, UAT y Prod

Fuente Mermaid del diagrama propio. La version vectorial esta en [diagrama.svg](diagrama.svg).

```mermaid
flowchart LR
  devDev["Desarrollador"] --> gh["GitHub: PR y Actions"]
  gh -->|"CI: fmt, validate, Checkov, Trivy, build"| img["Imagen traccar-avl:SHA"]
  img --> runner["Runner auto-hospedado en este equipo"]
  runner -->|"CD Dev automatico"| dev
  runner -->|"CD UAT automatico"| uat
  runner -->|"CD Prod con aprobacion"| prod

  subgraph floci["Floci en localhost:4566 (AWS emulado)"]
    subgraph dev["Dev :8282 / :5255"]
      dECS["ECS Traccar liviano"]
      dRDS["RDS Postgres"]
      dSM["Secrets Manager"]
    end
    subgraph uat["UAT :8182 / :5155"]
      uECS["ECS Traccar medio"]
      uRDS["RDS Postgres"]
      uSM["Secrets Manager"]
    end
    subgraph prod["Prod :8082 / :5055"]
      pECS["ECS Traccar 512/1024"]
      pRDS["RDS Postgres + backup 7d"]
      pSM["Secrets Manager + SSM"]
      pS3["S3 respaldos"]
      pCW["CloudWatch logs, dashboard y alarma"]
    end
    tfstate["S3 avl-tfstate + DynamoDB locks"]
  end

  sim["scripts/start-sim.sh OsmAnd"] --> prod
  sim -.-> uat
  sim -.-> dev
```

Notas:

- El estado de Terraform vive en Floci, con un key por ambiente (`dev/`, `uat/`, `prod/`).
- La misma imagen (SHA) se promueve; no se recompila en Prod.
- El simulador GPS apunta por defecto a Prod (puerto 5055) y acepta otra URL por variable.
