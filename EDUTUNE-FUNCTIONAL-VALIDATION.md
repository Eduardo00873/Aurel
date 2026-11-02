# EduTune — Relatório de validação funcional

Data: 2026-11-02 · Autor da validação: Claude Code (sessão automatizada) a pedido de Eduardo Carvalho

Estados usados: **APROVADO**, **FALHOU**, **PENDENTE** (requer validação manual), **NÃO APLICÁVEL**.

Regra seguida: só é marcado APROVADO o que foi efetivamente executado e verificado (por build, testes, inspeção do bundle, processo em execução ou logs do sistema). Nada que dependa de ouvir áudio, de interação física ou de diálogos de permissão foi dado como aprovado.

---

## 1. Ambiente

| Item | Valor |
|---|---|
| Máquina | MacBook Air (Mac16,12), Apple Silicon arm64 |
| macOS | 27.2 (26B123) |
| Xcode | 27.2 (27B52) |
| Swift (CLT) | 6.2.4 |
| Assinatura local | Nenhuma identidade de assinatura instalada → builds ad-hoc (`CODE_SIGN_IDENTITY=-`) |
| Dispositivos de saída observados | Altifalantes internos (`BuiltInSpeakerDevice`) e monitor externo (UID `06B3AD27-…`) |
| Apps com áudio observadas | Brave Browser, WhatsApp |

## 2. Código testado

| Item | Valor |
|---|---|
| Repositório local | `/Users/eduardocarvalho/Developer/FineTune` |
| Branch | `edutune/minimal-interface` |
| Commit | `a420befe03c68f27fbae109980a28a4fbbfaede7` (= `edutune/main`) |
| Working tree no início | limpo |

## 3. Testes automatizados

| Teste | Resultado | Detalhe |
|---|---|---|
| Build Debug (arm64) | **APROVADO** | `BUILD SUCCEEDED`, 0 erros, 2 avisos pré-existentes (Info.plist em Copy Bundle Resources; `AudioEngine.swift:272` `#ImplicitStrongCapture`) |
| Build Release (arm64) | **APROVADO** | `BUILD SUCCEEDED` |
| Testes unitários (`FineTuneTests`) | **APROVADO** | 758 executados, 758 aprovados, 0 falhados, 0 ignorados — idêntico à baseline |
| Testes de integração | **NÃO APLICÁVEL** | Não existe target de integração separado; os testes de engine com mocks estão incluídos nos 758 |
| Testes de UI (`FineTuneUITests`) | **NÃO APLICÁVEL** | O target existe no projeto mas não tem ficheiros-fonte no repositório (já assim no FineTune original; o CI original faz `-skip-testing:FineTuneUITests`). Ao incluí-lo, o runner falha com "não foi possível localizar o executável do bundle FineTuneUITests". Não é uma regressão. |
| `git diff --check` | **APROVADO** | Sem problemas |
| CI no GitHub (`ci.yml`, push de `a420bef`) | **APROVADO** | Run 41495862855: success, 1m39s |

## 4. Validação funcional

### A. Instalação e arranque
| Verificação | Estado | Evidência |
|---|---|---|
| Build Debug | **APROVADO** | ver §3 |
| Bundle ID `com.github.eduardo00873.EduTune` | **APROVADO** | `codesign -dv` e `Info.plist` do bundle |
| Nome da app e do executável = EduTune | **APROVADO** | `EduTune.app/Contents/MacOS/EduTune`, `CFBundleName = EduTune` |
| Instalação | **APROVADO** | Copiado para `~/Applications/EduTune.app` (sem privilégios de administrador) |
| Arranque sem crash (Debug) | **APROVADO** | Processo em execução de forma contínua; nenhum relatório de crash do EduTune Debug em `~/Library/Logs/DiagnosticReports` |
| Arranque sem crash (Release ad-hoc local) | **FALHOU** → contornado | Crash `dyld: Library missing` — Sparkle.framework rejeitado pela *library validation* (app e framework com assinaturas ad-hoc diferentes). Ver problema P1. Com re-assinatura `codesign --force --deep -s -` de uma cópia, arranca e corre normalmente. |
| Erros de arranque nos logs | **APROVADO** (com observações) | Sem erros da app além de: "No default device available …, deferring setup" (transitório, comportamento previsto do engine) e "Notification authorization error" (ver P5). Restantes erros são de frameworks do sistema (AppIntents, CoreBluetooth "No name or address", aviso de layout do AppKit) e não afetam o funcionamento. |
| Diretórios de dados independentes | **APROVADO** | `~/Library/Application Support/EduTune/{settings.json, autoeq-catalog.json}` criados/atualizados pelo EduTune; `~/Library/Application Support/FineTune/` sem modificações desde 17:41 (antes da renomeação). Preferências: domínios `com.github.eduardo00873.EduTune` e `com.finetuneapp.FineTune` separados. |

### B. Permissões macOS
| Verificação | Estado | Evidência / motivo |
|---|---|---|
| Pedido de Microfone e Gravação de Áudio do sistema no arranque | **APROVADO** (pedido emitido) | Logs TCC: `TCCAccessRequest service=kTCCServiceMicrophone` e `kTCCServiceAudioCapture` |
| Captura efetiva de áudio | **APROVADO** | Logs: "Tap activated" para Brave Browser e WhatsApp — os taps só são criados com a captura autorizada |
| Accessibility (teclas de média) | **APROVADO** (comportamento sem permissão) | TCC `kTCCServiceAccessibility` → `result=false`; a app regista "Media key tap removed" e continua a funcionar sem crash |
| Textos explicativos das permissões | **APROVADO** (conteúdo) / **PENDENTE** (apresentação) | Textos `NS*UsageDescription` com "EduTune …" confirmados no bundle; ver o diálogo no ecrã requer validação manual |
| Recusar e depois conceder permissões | **PENDENTE** | Exige interação em Definições do Sistema › Privacidade e Segurança; não foi alterado nenhum mecanismo de segurança |

### C. Deteção de aplicações
| Verificação | Estado | Evidência / motivo |
|---|---|---|
| Deteção de apps reais com áudio | **APROVADO** | Taps criados para Brave Browser e WhatsApp (processos reais) |
| Apps aparecem/desaparecem na lista | **PENDENTE** | Requer abrir o popup da barra de menus; a automação de ecrã não conseguiu aceder à app (instalada em `~/Applications`, assinatura ad-hoc) |
| Sem duplicados / entradas obsoletas | **PENDENTE** | Idem |
| Fechar e reabrir apps | **PENDENTE** | Idem |

### D. Volume individual
| Verificação | Estado | Motivo |
|---|---|---|
| Alterar volume de uma app; efeito real; 0 % / 50 % / 100 %; outras apps não afetadas; UI = áudio real | **PENDENTE** | Exige ouvir o resultado e manipular o slider. Lógica coberta por testes unitários (`VolumeMappingTests`, `ProcessingPipelineTests`, etc.), mas isso não substitui o teste real. |

### E. Mute individual
| Verificação | Estado | Motivo |
|---|---|---|
| Mute/unmute, só a app afetada, estado visual, mute + volume | **PENDENTE** | Exige interação e audição. Lógica coberta por `AudioEngineToggleMuteTests` e `MuteButtonColorInvariantTests`. |

### F. Dispositivo de saída
| Verificação | Estado | Evidência / motivo |
|---|---|---|
| Seguir a saída padrão do sistema ao mudar de dispositivo | **APROVADO** | Às 18:00:12 a saída mudou para o monitor externo e às 18:00:16 voltou; os logs mostram as duas apps a mudar de dispositivo ("Switching … CROSSFADE … Complete") sem erros nem crash. (A mudança não foi feita por esta sessão.) Para o WhatsApp, em silêncio, aparece "[CROSSFADE] Timeout at 0% – forcing completion": é a proteção prevista do engine para apps sem áudio, que termina normalmente. |
| Selecionar o dispositivo por app no popup | **PENDENTE** | Requer interação com a UI |
| Desligar / voltar a ligar um dispositivo | **PENDENTE** | Requer ação física (ex.: desligar auscultadores ou monitor) |

### G. Sincronização da interface
| Verificação | Estado | Motivo |
|---|---|---|
| Janela principal ↔ barra de menus | **NÃO APLICÁVEL** | A janela principal ainda não foi implementada (passo 5 do plano da auditoria). Hoje só existem o popup da barra de menus e a janela de definições. |
| Popup ↔ teclas de média / URL scheme `edutune://` | **PENDENTE** | Possível validar manualmente (ex.: `open "edutune://set-mute?app=com.brave.Browser&muted=true"` com o popup aberto) |

### H. Coexistência com o FineTune
| Verificação | Estado | Evidência |
|---|---|---|
| Identificadores distintos | **APROVADO** | Bundle IDs, domínios de preferências e esquemas de URL distintos |
| Diretórios distintos | **APROVADO** | ver A |
| Dispositivos internos distintos | **APROVADO** (código) | Criação, filtragem e limpeza usam `EduTune-`; o binário não contém `FineTune-`; o FineTune usa `FineTune-` → nenhum apaga ou mostra os dispositivos do outro |
| Permissões TCC | **APROVADO** | Os pedidos TCC usam o bundle ID do EduTune; as permissões são independentes das do FineTune |
| Execução simultânea | **NÃO TESTADO por decisão de segurança** | Ver §6. Os dois criariam taps `mutedWhenTapped` sobre os mesmos processos e interceptariam as mesmas teclas de média. Não foi forçado. |

## 5. Problemas identificados

| # | Problema | Causa | Impacto | Correção |
|---|---|---|---|---|
| P1 | Release ad-hoc local crasha no arranque | Hardened runtime + *library validation*: `Sparkle.framework` e o executável têm assinaturas ad-hoc diferentes ("mapping process and mapped file have different Team IDs") | Só em builds Release locais sem identidade de assinatura. Não afeta Debug nem builds assinados com Developer ID. Herdado do FineTune; não é regressão. | **Não aplicada** (seria alterar a configuração do projeto). Contorno: `codesign --force --deep -s - EduTune.app` numa cópia; solução definitiva: assinar com Apple Development/Developer ID. |
| P2 | `release.yml` e `scripts/build-dmg.sh` usam `build/FineTune.app` e `FineTune.dmg` | `PRODUCT_NAME` agora é EduTune → o produto é `EduTune.app` | O workflow de release (só com tags `v*`) e o script falhariam; o release também publicaria o appcast com URLs do FineTune | Não aplicada; ver recomendações §7 |
| P3 | Target `FineTuneUITests` vazio | Herdado do FineTune | `xcodebuild test` sem `-skip-testing` falha 1 caso | Não aplicada; usar `-skip-testing:FineTuneUITests` como o CI |
| P4 | Strings internas "FineTune" em logs | Subsistemas de log fixos (`com.finetuneapp.FineTune`) e a mensagem "No orphaned FineTune devices found" | Apenas cosmético (diagnóstico) | Não aplicada (fora do âmbito; decidido manter) |
| P5 | "Notification authorization error" no arranque | Pedido de permissão de notificações numa app ad-hoc; o erro concreto está oculto (`<private>`) | Os avisos de desconexão de dispositivo podem não aparecer | **PENDENTE**: verificar em Definições › Notificações; provavelmente resolvido com assinatura real |
| P6 | CPU em repouso ~13–16 % (Release), ~16–35 % (Debug) com 2 taps ativos e o popup fechado | `sample`: o main thread está ocioso; a carga está nas threads de I/O de áudio (2 IOProcs sempre ativos, `vDSP_biquad`) | Consumo de bateria. Pertence ao design do engine (taps permanentes); não foi comparado com o FineTune original | Não aplicada (exigiria mexer no motor de áudio). Recomendo medir o FineTune original nas mesmas condições antes de concluir que é anómalo. |

**Correções aplicadas ao código nesta fase: nenhuma.** Nenhum problema exigia uma correção pequena e segura dentro do âmbito: todos são de configuração ou assinatura, cosméticos, herdados ou do motor de áudio.

## 6. Coexistência com o FineTune — conclusão

O isolamento de identificadores, dados, preferências, permissões e dispositivos internos está correto. **Mesmo assim, não é seguro correr os dois em simultâneo:**
- ambos criariam taps `mutedWhenTapped` sobre os mesmos processos → o áudio de uma app poderia ser silenciado, duplicado ou ter o ganho aplicado duas vezes;
- ambos instalariam um event tap para as teclas de média → F10/F11/F12 seriam tratadas duas vezes;
- os atalhos globais (KeyboardShortcuts) podem colidir se forem configurados os mesmos.

Recomendação: usar só um dos dois de cada vez (sair do FineTune antes de abrir o EduTune).

## 7. Workflows do GitHub Actions

| Ficheiro | Situação | Recomendação |
|---|---|---|
| `.github/workflows/ci.yml` | **Relevante e funcional**: build + testes (scheme `FineTune`, sem assinatura, `-skip-testing:FineTuneUITests`). Passou no GitHub. Corre em `macos-26`; em repositório privado, os minutos macOS contam com multiplicador 10× sobre a quota gratuita. | Manter. Opcional: acrescentar `paths-ignore: ['**.md']` para não correr em alterações só de documentação. |
| `.github/workflows/release.yml` | **Específico do FineTune e incompatível**: dispara com tags `v*`; usa `build/FineTune.app`, `FineTune.dmg`, secrets de assinatura e notarização que o EduTune não tem, e gera `appcast.xml` com URLs `ronitsingh10/FineTune` e a chave Sparkle do autor original. | Não criar tags `v*` até ser adaptado. Mais tarde: desativar (`workflow_dispatch` só) ou reescrever para EduTune sem o passo do Sparkle. |
| `scripts/build-dmg.sh` | Mesmo problema de caminhos (`FineTune.app`) | Adaptar quando houver distribuição |
| `.github/FUNDING.yml` | Mostra o botão "Sponsor" com o Ko-fi de Ronit Singh no teu repositório | Remover (coerente com a remoção do botão Donate), ou manter conscientemente como crédito |
| `appcast.xml` | Feed de atualizações do FineTune; não é usado (Sparkle desativado) | Pode ficar; remover quando adaptares o release |

Nenhum workflow foi alterado nesta fase.

## 8. Limitações conhecidas
- Sem janela principal: a interface é só a barra de menus mais as definições.
- Sem identidade de assinatura: as permissões TCC ficam ligadas à assinatura ad-hoc e podem ser pedidas de novo a cada rebuild; o Release local precisa de re-assinatura (P1).
- Captura de áudio por processo exige macOS 14.4+ (alvo 15.4) e permissão de Gravação de Áudio do sistema.
- Não usar em simultâneo com o FineTune (§6).
- Atualizações automáticas desativadas: cada versão nova tem de ser instalada manualmente.
- Ícone da app ainda é o do FineTune.

## 9. Validação manual pendente (checklist)
1. Abrir o popup → confirmar que Brave/WhatsApp aparecem uma vez cada; fechar uma app → desaparece; reabrir → volta (C).
2. Com áudio em duas apps: volume 0 %, 50 %, 100 % numa → só essa muda; o valor da UI corresponde ao que se ouve (D).
3. Mute/unmute → só essa app; ícone vermelho = silêncio; mover o slider com mute ativo tira o mute (E).
4. Mudar o dispositivo de uma app no popup; desligar e voltar a ligar auscultadores ou monitor (F).
5. `open "edutune://set-mute?app=com.brave.Browser&muted=true"` com o popup aberto → o estado atualiza (G).
6. Definições do Sistema: recusar e depois conceder Gravação de Áudio e Acessibilidade; verificar Notificações (B, P5).

## 10. Avaliação final

| Área | Avaliação |
|---|---|
| Build e testes automatizados | Estável: 758/758, CI verde |
| Arranque, identidade e isolamento de dados | Estável (Debug); Release local só com assinatura correta |
| Captura e roteamento de áudio | Funciona em condições reais (taps ativos, mudança de saída tratada) |
| Controlo de volume/mute e UI | **Não verificado manualmente** |

**Conclusão:** o EduTune **ainda não pode ser considerado validado para uso normal**. Não foi encontrado nenhum defeito funcional, mas as funções centrais (volume, mute, seleção de dispositivo e lista de apps) estão PENDENTES de validação manual. Antes de considerar a app estável faltam: (1) executar a checklist §9; (2) adaptar ou desativar `release.yml` antes de qualquer tag; (3) assinar com uma identidade Apple Development para builds Release locais.
